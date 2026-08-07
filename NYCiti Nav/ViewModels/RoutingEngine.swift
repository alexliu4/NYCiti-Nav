import Foundation
import CoreLocation
import MapKit
import Observation

enum RoutingError: Error, LocalizedError {
    case unauthorized
    case serverError(Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized: Please check your API key in Secrets.plist."
        case .serverError(let code):
            return "Server returned error code \(code)."
        case .decodingFailed:
            return "Failed to parse transit data."
        }
    }
}

@Observable
class RoutingEngine {
    private let proxyURL = "https://nyc-transit-worker.transit-proxy.workers.dev/"
    private let trainRideBaseline: TimeInterval = 900 // 15 minutes default

    var routes: [MultimodalRoute] = []
    var selectedRoute: MultimodalRoute?
    var activePolyline: MKPolyline?

    // Detailed segment polylines for the entire multi-modal route
    var walkToDockPolyline: MKPolyline?
    var bikeToStationPolyline: MKPolyline?
    var trainPolyline: MKPolyline?
    var walkToDestPolyline: MKPolyline?

    var lastUserLocation: CLLocationCoordinate2D?

    func calculateRoutes(userLocation: CLLocationCoordinate2D, destination: CLLocationCoordinate2D? = nil, availableStations: [SubwayStation]) async {
        self.lastUserLocation = userLocation
        do {
            let transitData = try await fetchTransitData(lat: userLocation.latitude, lon: userLocation.longitude)

            let docksWithCoords = transitData.bikeStations.map { dock -> BikeStationProxy in
                var d = dock
                let offsetLat = Double.random(in: -0.001...0.001)
                let offsetLon = Double.random(in: -0.001...0.001)
                d.lat = userLocation.latitude + offsetLat
                d.lon = userLocation.longitude + offsetLon
                return d
            }

            let bestDock = docksWithCoords.first(where: { $0.bikes > 0 })

            let destinationStation = destination.flatMap { findNearestStation(to: $0, from: availableStations) }

            var calculatedOptions: [MultimodalRoute] = []

            for station in availableStations {
                let walkToDockDuration = bestDock != nil ? estimateWalkDuration(from: userLocation, to: CLLocationCoordinate2D(latitude: bestDock!.lat!, longitude: bestDock!.lon!)) : 0

                let bikeToStationDuration = bestDock != nil
                    ? estimateBikeDuration(from: CLLocationCoordinate2D(latitude: bestDock!.lat!, longitude: bestDock!.lon!), to: station.coordinate)
                    : estimateWalkDuration(from: userLocation, to: station.coordinate)

                let timeToPlatform = walkToDockDuration + bikeToStationDuration

                guard let stationArrivals = transitData.subwayTimes.first(where: { $0.stationId == station.id }) else {
                    continue
                }

                let allArrivals = stationArrivals.arrivals
                    .flatMap { $0.nextArrivals }
                    .sorted()

                let now = transitData.lastUpdated

                let validArrival = allArrivals.first { arrivalTimestamp in
                    let secondsToArrival = TimeInterval(arrivalTimestamp - now)
                    return secondsToArrival >= timeToPlatform
                }

                if let arrival = validArrival {
                    let secondsToArrival = TimeInterval(arrival - now)
                    let platformWait = secondsToArrival - timeToPlatform

                    let trainRideDuration: TimeInterval
                    let walkToDestinationDuration: TimeInterval

                    if let destStation = destinationStation, let destCoord = destination {
                        if station.id == destStation.id {
                            trainRideDuration = 0
                        } else {
                            let startLoc = CLLocation(latitude: station.lat, longitude: station.lon)
                            let endLoc = CLLocation(latitude: destStation.lat, longitude: destStation.lon)
                            trainRideDuration = startLoc.distance(from: endLoc) / 10.0 // average train speed 10 m/s (~22 mph)
                        }
                        walkToDestinationDuration = estimateWalkDuration(from: destStation.coordinate, to: destCoord)
                    } else {
                        trainRideDuration = trainRideBaseline
                        walkToDestinationDuration = 0
                    }

                    let totalTrip = timeToPlatform + platformWait + trainRideDuration + walkToDestinationDuration

                    let route = MultimodalRoute(
                        id: station.id,
                        station: station,
                        destinationStation: destinationStation,
                        startDock: bestDock,
                        walkToDockDuration: walkToDockDuration,
                        bikeDuration: bikeToStationDuration,
                        platformWaitDuration: platformWait,
                        trainRideDuration: trainRideDuration,
                        walkToDestinationDuration: walkToDestinationDuration,
                        totalTripDuration: totalTrip,
                        destinationLatitude: destination?.latitude,
                        destinationLongitude: destination?.longitude
                    )
                    calculatedOptions.append(route)
                }
            }

            self.routes = calculatedOptions.sorted(by: { $0.totalTripDuration < $1.totalTripDuration })

            if let fastest = self.routes.first {
                selectRoute(fastest)
            }

        } catch {
            print("Routing Error: \(error.localizedDescription)")
        }
    }

    func selectRoute(_ route: MultimodalRoute) {
        self.selectedRoute = route
        Task {
            await fetchAllRoutePolylines(for: route)
        }
    }

    private func fetchAllRoutePolylines(for route: MultimodalRoute) async {
        // Reset existing polylines
        await MainActor.run {
            self.walkToDockPolyline = nil
            self.bikeToStationPolyline = nil
            self.trainPolyline = nil
            self.walkToDestPolyline = nil
            self.activePolyline = nil
        }

        guard let userLoc = lastUserLocation else { return }

        // 1. Walk to Dock (if applicable)
        var dockCoord: CLLocationCoordinate2D? = nil
        if let dock = route.startDock, let dLat = dock.lat, let dLon = dock.lon {
            let coord = CLLocationCoordinate2D(latitude: dLat, longitude: dLon)
            dockCoord = coord
            if let poly = await fetchPolyline(from: userLoc, to: coord, transportType: .walking) {
                await MainActor.run {
                    self.walkToDockPolyline = poly
                }
            }
        }

        // 2. Bike to Station (or walk directly if no dock)
        let bikeStart = dockCoord ?? userLoc
        let bikeEnd = route.station.coordinate
        let transportType: MKDirectionsTransportType = dockCoord != nil ? .automobile : .walking
        if let poly = await fetchPolyline(from: bikeStart, to: bikeEnd, transportType: transportType) {
            await MainActor.run {
                self.bikeToStationPolyline = poly
                self.activePolyline = poly // Keep activePolyline for backwards compatibility
            }
        }

        // 3. Train from Start Station to End Station (if applicable)
        if let destStation = route.destinationStation {
            if route.station.id != destStation.id {
                let trainPoly = createStraightPolyline(from: route.station.coordinate, to: destStation.coordinate)
                await MainActor.run {
                    self.trainPolyline = trainPoly
                }
            }

            // 4. Walk from End Station to Destination Coordinate
            if let destCoord = route.destinationCoordinate {
                if let poly = await fetchPolyline(from: destStation.coordinate, to: destCoord, transportType: .walking) {
                    await MainActor.run {
                        self.walkToDestPolyline = poly
                    }
                }
            }
        }
    }

    private func fetchPolyline(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, transportType: MKDirectionsTransportType) async -> MKPolyline? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = transportType

        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            return response.routes.first?.polyline
        } catch {
            print("Polyline calculation failed: \(error)")
            return nil
        }
    }

    private func createStraightPolyline(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> MKPolyline {
        var coords = [start, end]
        return MKPolyline(coordinates: &coords, count: 2)
    }

    private func findNearestStation(to coordinate: CLLocationCoordinate2D, from stations: [SubwayStation]) -> SubwayStation? {
        guard !stations.isEmpty else { return nil }
        return stations.min { s1, s2 in
            let dist1 = CLLocation(latitude: s1.lat, longitude: s1.lon).distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            let dist2 = CLLocation(latitude: s2.lat, longitude: s2.lon).distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            return dist1 < dist2
        }
    }

    private func fetchTransitData(lat: Double, lon: Double) async throws -> TransitProxyResponse {
        var components = URLComponents(string: proxyURL)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lon", value: String(lon))
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(Secrets.apiKey, forHTTPHeaderField: "X-App-API-Key")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                throw RoutingError.unauthorized
            } else if !(200...299).contains(httpResponse.statusCode) {
                throw RoutingError.serverError(httpResponse.statusCode)
            }
        }

        do {
            return try JSONDecoder().decode(TransitProxyResponse.self, from: data)
        } catch {
            throw RoutingError.decodingFailed
        }
    }

    private func estimateBikeDuration(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> TimeInterval {
        let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return startLoc.distance(from: endLoc) / 5.36
    }

    private func estimateWalkDuration(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> TimeInterval {
        let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return startLoc.distance(from: endLoc) / 1.4
    }
}

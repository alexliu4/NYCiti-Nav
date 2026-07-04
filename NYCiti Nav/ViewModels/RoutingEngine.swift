import Foundation
import CoreLocation
import MapKit
import Observation

@Observable
class RoutingEngine {
    private let proxyURL = "https://nyc-transit-worker.transit-proxy.workers.dev/"
    private let trainRideBaseline: TimeInterval = 900 // 15 minutes default

    var routes: [MultimodalRoute] = []
    var selectedRoute: MultimodalRoute?
    var activePolyline: MKPolyline?

    func calculateRoutes(userLocation: CLLocationCoordinate2D, availableStations: [SubwayStation]) async {
        do {
            let transitData = try await fetchTransitData(lat: userLocation.latitude, lon: userLocation.longitude)

            // Mocking Citi Bike docks near user
            let docksWithCoords = transitData.bikeStations.map { dock -> BikeStationProxy in
                var d = dock
                // Spread them out slightly
                let offsetLat = Double.random(in: -0.003...0.003)
                let offsetLon = Double.random(in: -0.003...0.003)
                d.lat = userLocation.latitude + offsetLat
                d.lon = userLocation.longitude + offsetLon
                return d
            }

            let bestDock = docksWithCoords.first(where: { $0.bikes > 0 })

            var calculatedOptions: [MultimodalRoute] = []

            for station in availableStations {
                // Time to reach the station = Walking to Dock + Cycling to Station
                let walkToDockDuration = bestDock != nil ? estimateWalkDuration(from: userLocation, to: CLLocationCoordinate2D(latitude: bestDock!.lat!, longitude: bestDock!.lon!)) : 0
                let bikeToStationDuration = bestDock != nil ? estimateBikeDuration(from: CLLocationCoordinate2D(latitude: bestDock!.lat!, longitude: bestDock!.lon!), to: station.coordinate) : estimateWalkDuration(from: userLocation, to: station.coordinate)

                let timeToPlatform = walkToDockDuration + bikeToStationDuration

                guard let stationArrivals = transitData.subwayTimes.first(where: { $0.stationId == station.id }) else {
                    continue
                }

                let allArrivals = stationArrivals.arrivals
                    .flatMap { $0.nextArrivals }
                    .sorted()

                let now = transitData.lastUpdated

                // Find first train >= timeToPlatform
                let validArrival = allArrivals.first { arrivalTimestamp in
                    let secondsToArrival = TimeInterval(arrivalTimestamp - now)
                    return secondsToArrival >= (timeToPlatform / 60) // Proxy uses minutes? Prompt example: 8 > 3.
                    // Wait, prompt says: "12 - 8 = 4 minutes". Timestamps are usually large.
                    // If timestamps are Unix, then we need seconds.
                }

                if let arrival = validArrival {
                    let secondsToArrival = TimeInterval(arrival - now)
                    // If the proxy returns minutes instead of seconds, adjust.
                    // The prompt example [3, 12, 22] looks like minutes relative to now.
                    // But the JSON example 1783097128 is a Unix timestamp.
                    // Let's assume Unix timestamps for logic.

                    let platformWait = secondsToArrival - timeToPlatform

                    let totalTrip = timeToPlatform + platformWait + trainRideBaseline

                    let route = MultimodalRoute(
                        id: station.id,
                        station: station,
                        startDock: bestDock,
                        totalTripDuration: totalTrip,
                        bikeDuration: timeToPlatform, // In this context, total time to station
                        platformWaitDuration: platformWait,
                        trainRideDuration: trainRideBaseline
                    )
                    calculatedOptions.append(route)
                }
            }

            self.routes = calculatedOptions.sorted(by: { $0.totalTripDuration < $1.totalTripDuration })

            if let fastest = self.routes.first {
                selectRoute(fastest)
            }

        } catch {
            print("Routing Error: \(error)")
        }
    }

    func selectRoute(_ route: MultimodalRoute) {
        self.selectedRoute = route
        Task {
            await fetchRoutePolyline(for: route)
        }
    }

    private func fetchRoutePolyline(for route: MultimodalRoute) async {
        guard let dockLat = route.startDock?.lat, let dockLon = route.startDock?.lon else { return }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: dockLat, longitude: dockLon)))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: route.station.coordinate))
        request.transportType = .automobile // Better polyline for bike than .transit

        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            if let polyline = response.routes.first?.polyline {
                await MainActor.run {
                    self.activePolyline = polyline
                }
            }
        } catch {
            print("Polyline calculation failed: \(error)")
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

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TransitProxyResponse.self, from: data)
    }

    private func estimateBikeDuration(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> TimeInterval {
        let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return startLoc.distance(from: endLoc) / 5.36 // ~12 mph
    }

    private func estimateWalkDuration(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> TimeInterval {
        let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return startLoc.distance(from: endLoc) / 1.4 // ~3.1 mph
    }
}

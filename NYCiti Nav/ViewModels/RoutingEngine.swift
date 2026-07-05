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

    func calculateRoutes(userLocation: CLLocationCoordinate2D, destination: CLLocationCoordinate2D? = nil, availableStations: [SubwayStation]) async {
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

            var calculatedOptions: [MultimodalRoute] = []

            for station in availableStations {
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

                let validArrival = allArrivals.first { arrivalTimestamp in
                    let secondsToArrival = TimeInterval(arrivalTimestamp - now)
                    return secondsToArrival >= timeToPlatform
                }

                if let arrival = validArrival {
                    let secondsToArrival = TimeInterval(arrival - now)
                    let platformWait = secondsToArrival - timeToPlatform

                    let totalTrip = timeToPlatform + platformWait + trainRideBaseline

                    let route = MultimodalRoute(
                        id: station.id,
                        station: station,
                        startDock: bestDock,
                        totalTripDuration: totalTrip,
                        bikeDuration: timeToPlatform,
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
            print("Routing Error: \(error.localizedDescription)")
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
        request.transportType = .automobile

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
            URLQueryItem(name: "lan", value: String(lat)),
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

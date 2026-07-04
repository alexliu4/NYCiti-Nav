import Foundation
import CoreLocation
import Observation

@Observable
class RoutingEngine {
    private let proxyURL = "https://nyc-transit-worker.transit-proxy.workers.dev/"
    private let apiKey = "YOUR_API_KEY" // Placeholder
    private let trainRideBaseline: TimeInterval = 900 // 15 minutes default

    var routes: [MultimodalRoute] = []

    func calculateRoutes(userLocation: CLLocationCoordinate2D, availableStations: [SubwayStation]) async {
        do {
            let transitData = try await fetchTransitData(lat: userLocation.latitude, lon: userLocation.longitude)

            var calculatedOptions: [MultimodalRoute] = []

            for station in availableStations {
                // 1. Get cycling duration (mocking Sprint 3 parallel cycling ETAs)
                // In a real app, this would use MKDirections or a specialized service
                let bikeDuration = estimateBikeDuration(from: userLocation, to: station.coordinate)

                // 2. Find live arrivals for this station from proxy
                guard let stationArrivals = transitData.subwayTimes.first(where: { $0.stationId == station.id }) else {
                    continue // Exclude if no arrivals
                }

                // 3. Time-matching logical loop
                // Flatten all arrivals into a single sorted array of timestamps
                let allArrivals = stationArrivals.arrivals
                    .flatMap { $0.nextArrivals }
                    .sorted()

                let now = transitData.lastUpdated

                // Find the first train arrival that is >= bikeDuration
                // (Arrival timestamps are absolute Unix times, we need relative offset)
                let validArrival = allArrivals.first { arrivalTimestamp in
                    let secondsToArrival = TimeInterval(arrivalTimestamp - now)
                    return secondsToArrival >= bikeDuration
                }

                if let arrival = validArrival {
                    let secondsToArrival = TimeInterval(arrival - now)
                    let platformWait = secondsToArrival - bikeDuration

                    let totalTrip = bikeDuration + platformWait + trainRideBaseline

                    let route = MultimodalRoute(
                        station: station,
                        totalTripDuration: totalTrip,
                        bikeDuration: bikeDuration,
                        platformWaitDuration: platformWait,
                        trainRideDuration: trainRideBaseline
                    )
                    calculatedOptions.append(route)
                }
            }

            // 4. Sort by total duration ascending
            self.routes = calculatedOptions.sorted(by: { $0.totalTripDuration < $1.totalTripDuration })

        } catch {
            print("Routing Error: \(error)")
        }
    }

    private func fetchTransitData(lat: Double, lon: Double) async throws -> TransitProxyResponse {
        var components = URLComponents(string: proxyURL)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lon", value: String(lon))
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "X-App-API-Key")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TransitProxyResponse.self, from: data)
    }

    /// Mocking the cycling duration estimate from Sprint 3
    private func estimateBikeDuration(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> TimeInterval {
        let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
        let distance = startLoc.distance(from: endLoc)

        // Average biking speed: 12 mph (~5.36 m/s)
        return distance / 5.36
    }
}

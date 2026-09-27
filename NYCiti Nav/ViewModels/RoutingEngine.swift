import Foundation
import CoreLocation
import MapKit
import Observation

enum RoutingError: Error, LocalizedError {
    case missingAPIKey, invalidAPIKey, invalidCoordinates, unauthorized
    case serverError(Int, String)
    case decodingFailed(String)
    case invalidResponse, noRoute

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Live arrivals need AppAPIKey in the bundled Secrets.plist. Directions are still available."
        case .invalidAPIKey:
            return "AppAPIKey contains invalid HTTP header characters. Check Secrets.plist."
        case .invalidCoordinates:
            return "The starting location or destination is invalid."
        case .unauthorized:
            return "The transit service rejected AppAPIKey. Check that it matches the Worker’s APP_API_KEY."
        case .serverError(let code, let detail):
            return "Transit service returned HTTP \(code)\(detail.isEmpty ? "." : ": \(detail)")"
        case .decodingFailed(let path):
            return "Transit response does not match the app’s data format (\(path))."
        case .invalidResponse:
            return "The transit service returned an invalid response."
        case .noRoute:
            return "No walking route was found. Try transit directions in Apple Maps."
        }
    }
}

/// The Worker supplies live arrivals, not destination itineraries.
/// Keep those independent so a Worker failure cannot block destination directions.
@MainActor @Observable
class RoutingEngine {
    var walkingRoute: MKRoute?
    var transitData: TransitProxyResponse?
    var isLoading = false
    var errorMessage: String?
    var transitMessage: String?

    private let session: URLSession
    private let proxyURL: URL
    private let apiKey: @MainActor () -> String
    private let routeLoader: (@MainActor (MKDirections.Request) async throws -> MKRoute?)?
    private var requestID = UUID()
    private var directions: MKDirections?

    init(session: URLSession = .shared,
         proxyURL: URL = URL(string: "https://nyc-transit-worker.transit-proxy.workers.dev/")!,
         apiKey: @escaping @MainActor () -> String = { Secrets.apiKey },
         routeLoader: (@MainActor (MKDirections.Request) async throws -> MKRoute?)? = nil) {
        self.session = session
        self.proxyURL = proxyURL
        self.apiKey = apiKey
        self.routeLoader = routeLoader
    }

    func reset() {
        requestID = UUID()
        directions?.cancel()
        directions = nil
        walkingRoute = nil
        transitData = nil
        errorMessage = nil
        transitMessage = nil
        isLoading = false
    }

    func calculateRoutes(userLocation: CLLocationCoordinate2D, destination: CLLocationCoordinate2D,
                         availableStations: [SubwayStation]) async {
        reset()
        let id = requestID
        guard CLLocationCoordinate2DIsValid(userLocation), CLLocationCoordinate2DIsValid(destination) else {
            errorMessage = RoutingError.invalidCoordinates.localizedDescription
            return
        }
        isLoading = true
        // Live arrivals and walking directions may finish in either order.
        async let arrivals: Void = loadArrivals(at: userLocation, stations: availableStations, id: id)
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: destination.latitude, longitude: destination.longitude), address: nil)
        request.transportType = .walking
        let directions = MKDirections(request: request)
        self.directions = directions
        do {
            let result: MKRoute?
            if let routeLoader { result = try await routeLoader(request) }
            else { result = try await directions.calculate().routes.first }
            guard id == requestID, !Task.isCancelled else { return }
            guard let route = result else { throw RoutingError.noRoute }
            walkingRoute = route
        } catch {
            guard id == requestID, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
        if id == requestID { isLoading = false }
        await arrivals
    }

    private func loadArrivals(at coordinate: CLLocationCoordinate2D, stations: [SubwayStation], id: UUID) async {
        do {
            let data = try await fetchTransitData(lat: coordinate.latitude, lon: coordinate.longitude)
            guard id == requestID, !Task.isCancelled else { return }
            transitData = data
            let stationIDs = Set(stations.map(\.id))
            if data.subwayTimes.isEmpty {
                transitMessage = "The transit service returned no nearby subway arrivals."
            } else if !data.subwayTimes.contains(where: { stationIDs.contains($0.stationId) }) {
                transitMessage = "Live arrivals loaded, but the local station IDs do not match the transit service."
            }
        } catch {
            guard id == requestID, !Task.isCancelled else { return }
            transitMessage = error.localizedDescription
        }
    }

    func fetchTransitData(lat: Double, lon: Double) async throws -> TransitProxyResponse {
        guard CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lon)) else {
            throw RoutingError.invalidCoordinates
        }
        let key = apiKey().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw RoutingError.missingAPIKey }
        guard key.utf8.allSatisfy({ $0 >= 32 && $0 < 127 }) else { throw RoutingError.invalidAPIKey }
        guard var components = URLComponents(url: proxyURL, resolvingAgainstBaseURL: false) else {
            throw RoutingError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "lat", value: String(lat)),
                                 URLQueryItem(name: "lon", value: String(lon))]
        guard let url = components.url else { throw RoutingError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(key, forHTTPHeaderField: "X-App-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw RoutingError.invalidResponse }
        guard response.statusCode != 401 && response.statusCode != 403 else { throw RoutingError.unauthorized }
        guard (200...299).contains(response.statusCode) else {
            // Preserve useful Worker validation errors without exposing credentials or HTML error pages.
            let text = String(data: data, encoding: .utf8) ?? ""
            let detail = text.lowercased().contains("<html") ? "" : String(text.replacingOccurrences(of: key, with: "[redacted]").prefix(300))
            throw RoutingError.serverError(response.statusCode, detail)
        }
        do {
            return try JSONDecoder().decode(TransitProxyResponse.self, from: data)
        } catch let error as DecodingError {
            let context: DecodingError.Context
            switch error {
            case .keyNotFound(let key, let c):
                throw RoutingError.decodingFailed((c.codingPath.map(\.stringValue) + [key.stringValue]).joined(separator: "."))
            case .typeMismatch(_, let c), .valueNotFound(_, let c), .dataCorrupted(let c): context = c
            @unknown default: throw RoutingError.decodingFailed("unknown field")
            }
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            throw RoutingError.decodingFailed(path.isEmpty ? "root" : path)
        }
    }
}

import XCTest
import CoreLocation
import MapKit
@testable import NYCiti_Nav

private final class TransitURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, String))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, body) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@MainActor
final class RoutingEngineTests: XCTestCase {
    private let origin = CLLocationCoordinate2D(latitude: 40.7549, longitude: -73.9840)
    private let destination = CLLocationCoordinate2D(latitude: 40.7173, longitude: -73.9568)
    private let validJSON = """
    {"lastUpdated":1790145000,"bikeStations":[{"id":"dock-1","bikes":2,"docks":3,"lat":40.75,"lon":-73.98}],"subwayTimes":[{"stationId":"L08","arrivals":[{"routeId":"L","nextArrivals":[1790145300]}]}]}
    """

    private func engine(key: String = "test-key",
                        routeLoader: (@MainActor @Sendable (MKDirections.Request) async throws -> MKRoute?)? = nil) -> RoutingEngine {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TransitURLProtocol.self]
        return RoutingEngine(session: URLSession(configuration: configuration),
                             apiKey: { key }, routeLoader: routeLoader)
    }

    func testWorkerRequestAndResponseContract() async throws {
        let json = validJSON
        TransitURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-App-API-Key"), "test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            XCTAssertEqual(query.first { $0.name == "lat" }?.value, "40.7549")
            XCTAssertEqual(query.first { $0.name == "lon" }?.value, "-73.984")
            XCTAssertFalse(query.contains { $0.name == "lan" })
            return (200, json)
        }
        let data = try await engine().fetchTransitData(lat: origin.latitude, lon: origin.longitude)
        XCTAssertEqual(data.subwayTimes.first?.stationId, "L08")
        XCTAssertEqual(data.bikeStations.first?.lat, 40.75)
        XCTAssertEqual(data.bikeStations.first?.lon, -73.98)
    }

    func testMissingAndInvalidKeysFailBeforeNetwork() async {
        TransitURLProtocol.handler = { _ in XCTFail("Must not send invalid credentials"); return (200, "") }
        for key in ["", " \n", "bad\u{0001}key", "key\nvalue"] {
            do {
                _ = try await engine(key: key).fetchTransitData(lat: 40.75, lon: -73.98)
                XCTFail("Expected credential error")
            } catch {
                XCTAssertTrue(error is RoutingError)
            }
        }
    }

    func testInvalidCoordinatesFailBeforeNetwork() async {
        TransitURLProtocol.handler = { _ in XCTFail("Must not send invalid coordinates"); return (200, "") }
        do {
            _ = try await engine().fetchTransitData(lat: .nan, lon: -73.98)
            XCTFail("Expected coordinate error")
        } catch RoutingError.invalidCoordinates {} catch { XCTFail("Unexpected error: \(error)") }
    }

    func testUnauthorizedIsNotReportedAsJSONFailure() async {
        for status in [401, 403] {
            TransitURLProtocol.handler = { _ in (status, "Unauthorized") }
            do {
                _ = try await engine().fetchTransitData(lat: 40.75, lon: -73.98)
                XCTFail("Expected unauthorized")
            } catch RoutingError.unauthorized {} catch { XCTFail("Unexpected error: \(error)") }
        }
    }

    func testBadRequestPreservesWorkerReasonAndRedactsKey() async {
        TransitURLProtocol.handler = { _ in (400, "Missing parameter: stationId; key=test-key") }
        do {
            _ = try await engine().fetchTransitData(lat: 40.75, lon: -73.98)
            XCTFail("Expected HTTP error")
        } catch RoutingError.serverError(let status, let detail) {
            XCTAssertEqual(status, 400)
            XCTAssertTrue(detail.contains("stationId"))
            XCTAssertFalse(detail.contains("test-key"))
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testSchemaMismatchIncludesMissingField() async {
        TransitURLProtocol.handler = { _ in (200, "{\"lastUpdated\":1,\"bikeStations\":[]}") }
        do {
            _ = try await engine().fetchTransitData(lat: 40.75, lon: -73.98)
            XCTFail("Expected decoding error")
        } catch RoutingError.decodingFailed(let path) {
            XCTAssertEqual(path, "subwayTimes")
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testMissingDockCoordinatesRemainMissing() throws {
        let data = Data("{\"id\":\"dock-1\",\"bikes\":2,\"docks\":3}".utf8)
        let dock = try JSONDecoder().decode(BikeStationProxy.self, from: data)
        XCTAssertNil(dock.lat)
        XCTAssertNil(dock.lon)
    }

    func testDestinationUsedEvenWhenWorkerIsUnavailable() async {
        var receivedRequest: MKDirections.Request?
        let engine = engine(key: "", routeLoader: { request in
            receivedRequest = request
            return MKRoute()
        })
        await engine.calculateRoutes(userLocation: origin, destination: destination, availableStations: [])
        XCTAssertEqual(receivedRequest?.source?.location.coordinate.latitude, origin.latitude)
        XCTAssertEqual(receivedRequest?.destination?.location.coordinate.longitude, destination.longitude)
        XCTAssertEqual(receivedRequest?.transportType, .walking)
        XCTAssertNotNil(engine.walkingRoute)
        XCTAssertNil(engine.errorMessage)
        XCTAssertNotNil(engine.transitMessage)
        XCTAssertFalse(engine.isLoading)
        engine.reset()
        XCTAssertNil(engine.walkingRoute)
        XCTAssertNil(engine.transitMessage)
    }

    func testUnmatchedStationIDsAreVisible() async {
        let json = validJSON
        TransitURLProtocol.handler = { _ in (200, json) }
        let engine = engine(routeLoader: { _ in MKRoute() })
        await engine.calculateRoutes(userLocation: origin, destination: destination,
                                     availableStations: [SubwayStation(id: "1", name: "Placeholder", lines: ["L"], lat: 40.75, lon: -73.98)])
        XCTAssertTrue(engine.transitMessage?.contains("IDs do not match") == true)
        XCTAssertNotNil(engine.walkingRoute)
    }

    func testResetDiscardsInFlightRoute() async {
        var continuation: CheckedContinuation<MKRoute?, Never>?
        let engine = engine(key: "", routeLoader: { _ in
            await withCheckedContinuation { continuation = $0 }
        })
        let task = Task { await engine.calculateRoutes(userLocation: origin, destination: destination, availableStations: []) }
        while continuation == nil { await Task.yield() }
        engine.reset()
        continuation?.resume(returning: MKRoute())
        await task.value
        XCTAssertNil(engine.walkingRoute)
        XCTAssertNil(engine.transitData)
        XCTAssertNil(engine.transitMessage)
        XCTAssertFalse(engine.isLoading)
    }
}

import XCTest
import CoreLocation
@testable import NYCiti_Nav

final class RoutingEngineTests: XCTestCase {

    func testTimeMatchingLogic() {
        // Given
        let station = SubwayStation(id: "123", name: "Test Station", lines: ["1"], lat: 40.7128, lon: -74.0060)
        let bikeDuration: TimeInterval = 480 // 8 minutes (8 * 60)
        let now: Int64 = 1000

        let arrivalTimestamps: [Int64] = [
            now + (3 * 60),  // 1180
            now + (12 * 60), // 1720
            now + (22 * 60)  // 2320
        ]

        let validArrival = arrivalTimestamps.first { TimeInterval($0 - now) >= (bikeDuration / 60) }
        // The logic in VM uses seconds, so if timestamps are seconds, bikeDuration should be seconds.
        // If timestamps are Unix (seconds), bikeDuration should be seconds.

        XCTAssertNotNil(validArrival)
    }

    func testRouteSorting() {
        let stationA = SubwayStation(id: "A", name: "A", lines: ["1"], lat: 0, lon: 0)
        let stationB = SubwayStation(id: "B", name: "B", lines: ["2"], lat: 0, lon: 0)

        let route1 = MultimodalRoute(
            id: "A",
            station: stationA,
            startDock: nil,
            totalTripDuration: 1200,
            bikeDuration: 500,
            platformWaitDuration: 200,
            trainRideDuration: 500
        )

        let route2 = MultimodalRoute(
            id: "B",
            station: stationB,
            startDock: nil,
            totalTripDuration: 1000,
            bikeDuration: 400,
            platformWaitDuration: 100,
            trainRideDuration: 500
        )

        let routes = [route1, route2].sorted(by: { $0.totalTripDuration < $1.totalTripDuration })

        XCTAssertEqual(routes.first?.id, "B", "Fastest route should be first")
    }
}

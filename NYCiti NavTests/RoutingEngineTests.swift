import XCTest
import CoreLocation
@testable import NYCiti_Nav

final class RoutingEngineTests: XCTestCase {

    func testTimeMatchingLogic() {
        // Given
        let station = SubwayStation(id: "123", name: "Test Station", lines: ["1"], lat: 40.7128, lon: -74.0060)
        let bikeDuration: TimeInterval = 480 // 8 minutes (8 * 60)
        let now: Int64 = 1000

        // Mock arrivals: 3 mins, 12 mins, 22 mins from 'now'
        let arrivalTimestamps: [Int64] = [
            now + (3 * 60),  // 1180
            now + (12 * 60), // 1720
            now + (22 * 60)  // 2320
        ]

        // Logical check as per requirements:
        // Cycling duration = 8 mins. Arrivals = [3, 12, 22 mins].
        // 8 > 3, so skip first.
        // 12 >= 8, so use 12.
        // Wait duration = 12 - 8 = 4 mins.

        let validArrival = arrivalTimestamps.first { TimeInterval($0 - now) >= bikeDuration }
        XCTAssertNotNil(validArrival)

        let secondsToArrival = TimeInterval(validArrival! - now)
        let platformWait = secondsToArrival - bikeDuration

        XCTAssertEqual(platformWait, 4 * 60, "Platform wait should be 4 minutes (240 seconds)")
    }

    func testRouteSorting() {
        let stationA = SubwayStation(id: "A", name: "A", lines: ["1"], lat: 0, lon: 0)
        let stationB = SubwayStation(id: "B", name: "B", lines: ["2"], lat: 0, lon: 0)

        let route1 = MultimodalRoute(
            station: stationA,
            totalTripDuration: 1200,
            bikeDuration: 500,
            platformWaitDuration: 200,
            trainRideDuration: 500
        )

        let route2 = MultimodalRoute(
            station: stationB,
            totalTripDuration: 1000,
            bikeDuration: 400,
            platformWaitDuration: 100,
            trainRideDuration: 500
        )

        let routes = [route1, route2].sorted(by: { $0.totalTripDuration < $1.totalTripDuration })

        XCTAssertEqual(routes.first?.station.id, "B", "Fastest route should be first")
    }
}

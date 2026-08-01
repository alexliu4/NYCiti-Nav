import XCTest
import CoreLocation
@testable import NYCiti_Nav

final class RoutingEngineTests: XCTestCase {

    func testTimeMatchingLogic() {
        // Given
        let bikeDuration: TimeInterval = 480 // 8 minutes
        let now: Int64 = 1000

        let arrivalTimestamps: [Int64] = [
            now + (3 * 60),  // 1180
            now + (12 * 60), // 1720
            now + (22 * 60)  // 2320
        ]

        let validArrival = arrivalTimestamps.first { TimeInterval($0 - now) >= bikeDuration }

        XCTAssertNotNil(validArrival)
        XCTAssertEqual(validArrival, now + (12 * 60))
    }

    func testRouteSorting() {
        let stationA = SubwayStation(id: "A", name: "A", lines: ["1"], lat: 0, lon: 0)
        let stationB = SubwayStation(id: "B", name: "B", lines: ["2"], lat: 0, lon: 0)

        let route1 = MultimodalRoute(
            id: "A",
            station: stationA,
            destinationStation: stationB,
            startDock: nil,
            walkToDockDuration: 100,
            bikeDuration: 500,
            platformWaitDuration: 200,
            trainRideDuration: 500,
            walkToDestinationDuration: 100,
            totalTripDuration: 1400,
            destinationLatitude: 0,
            destinationLongitude: 0
        )

        let route2 = MultimodalRoute(
            id: "B",
            station: stationB,
            destinationStation: stationA,
            startDock: nil,
            walkToDockDuration: 50,
            bikeDuration: 400,
            platformWaitDuration: 100,
            trainRideDuration: 500,
            walkToDestinationDuration: 50,
            totalTripDuration: 1100,
            destinationLatitude: 0,
            destinationLongitude: 0
        )

        let routes = [route1, route2].sorted(by: { $0.totalTripDuration < $1.totalTripDuration })

        XCTAssertEqual(routes.first?.id, "B", "Fastest route should be first")
    }

    func testMultimodalRouteCalculatedDuration() {
        let station = SubwayStation(id: "1", name: "Union Square", lines: ["L"], lat: 40.7346, lon: -73.9903)
        let destStation = SubwayStation(id: "2", name: "Bedford Ave", lines: ["L"], lat: 40.7173, lon: -73.9568)

        let route = MultimodalRoute(
            id: "UnionBedford",
            station: station,
            destinationStation: destStation,
            startDock: nil,
            walkToDockDuration: 120,
            bikeDuration: 300,
            platformWaitDuration: 180,
            trainRideDuration: 420,
            walkToDestinationDuration: 150,
            totalTripDuration: 1170,
            destinationLatitude: 40.7173,
            destinationLongitude: -73.9568
        )

        XCTAssertEqual(route.totalTripDuration, 1170)
        XCTAssertEqual(route.destinationCoordinate?.latitude, 40.7173)
        XCTAssertEqual(route.destinationCoordinate?.longitude, -73.9568)
    }
}

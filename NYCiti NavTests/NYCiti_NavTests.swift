import XCTest
@testable import NYCiti_Nav

final class NYCiti_NavTests: XCTestCase {

    func testSubwayStationDecoding() throws {
        let json = """
        {
            "id": "1",
            "name": "Test Station",
            "lines": ["A", "B", "C"],
            "lat": 40.7128,
            "lon": -74.0060
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let station = try decoder.decode(SubwayStation.self, from: json)

        XCTAssertEqual(station.id, "1")
        XCTAssertEqual(station.name, "Test Station")
        XCTAssertEqual(station.lines, ["A", "B", "C"])
        XCTAssertEqual(station.lat, 40.7128)
        XCTAssertEqual(station.lon, -74.0060)
    }

    func testSubwayStationCoordinate() throws {
        let station = SubwayStation(id: "1", name: "Test", lines: ["A"], lat: 40.0, lon: -70.0)
        XCTAssertEqual(station.coordinate.latitude, 40.0)
        XCTAssertEqual(station.coordinate.longitude, -70.0)
    }

    func testPrimaryColorLogic() throws {
        let hubStation = SubwayStation(id: "1", name: "Hub", lines: ["A", "B"], lat: 0, lon: 0)
        XCTAssertEqual(hubStation.primaryColor, .gray)

        let singleLineStation = SubwayStation(id: "2", name: "Single", lines: ["1"], lat: 0, lon: 0)
        // Red color for line 1: RGB(238, 53, 46)
        XCTAssertNotEqual(singleLineStation.primaryColor, .gray)
    }
}

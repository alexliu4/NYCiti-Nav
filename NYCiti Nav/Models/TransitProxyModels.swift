import Foundation

struct TransitProxyResponse: Codable {
    let lastUpdated: Int64
    let bikeStations: [BikeStationProxy]
    let subwayTimes: [SubwayTimeProxy]
}

struct BikeStationProxy: Codable, Identifiable {
    let id: String
    let bikes: Int
    let docks: Int
    // Coordinates must come from station information supplied by the Worker.
    // Missing coordinates must never be replaced with fabricated locations.
    var lat: Double?
    var lon: Double?
}

struct SubwayTimeProxy: Codable {
    let stationId: String
    let arrivals: [ArrivalProxy]
}

struct ArrivalProxy: Codable {
    let routeId: String
    let nextArrivals: [Int64] // Unix timestamps
}

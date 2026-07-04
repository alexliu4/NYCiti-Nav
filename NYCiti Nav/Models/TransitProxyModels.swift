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
    // In a real app, these would have coordinates.
    // We'll mock them in the RoutingEngine based on a radius around the user for this prototype.
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

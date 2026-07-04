import Foundation

struct TransitProxyResponse: Codable {
    let lastUpdated: Int64
    let bikeStations: [BikeStationProxy]
    let subwayTimes: [SubwayTimeProxy]
}

struct BikeStationProxy: Codable {
    let id: String
    let bikes: Int
    let docks: Int
}

struct SubwayTimeProxy: Codable {
    let stationId: String
    let arrivals: [ArrivalProxy]
}

struct ArrivalProxy: Codable {
    let routeId: String
    let nextArrivals: [Int64] // Unix timestamps
}

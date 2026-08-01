import Foundation
import MapKit

struct MultimodalRoute: Identifiable, Codable {
    let id: String
    let station: SubwayStation
    let destinationStation: SubwayStation?
    let startDock: BikeStationProxy?

    let walkToDockDuration: TimeInterval
    let bikeDuration: TimeInterval
    let platformWaitDuration: TimeInterval
    let trainRideDuration: TimeInterval
    let walkToDestinationDuration: TimeInterval
    let totalTripDuration: TimeInterval

    let destinationLatitude: Double?
    let destinationLongitude: Double?

    var destinationCoordinate: CLLocationCoordinate2D? {
        guard let lat = destinationLatitude, let lon = destinationLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    static func < (lhs: MultimodalRoute, rhs: MultimodalRoute) -> Bool {
        lhs.totalTripDuration < rhs.totalTripDuration
    }
}

import Foundation
import MapKit

struct MultimodalRoute: Identifiable, Codable {
    let id: String
    let station: SubwayStation
    let startDock: BikeStationProxy?
    let totalTripDuration: TimeInterval
    let bikeDuration: TimeInterval
    let platformWaitDuration: TimeInterval
    let trainRideDuration: TimeInterval

    // Polyline geometry is not Codable, we'll store it separately in the VM or use a wrapper
    // For now, id will be station.id

    static func < (lhs: MultimodalRoute, rhs: MultimodalRoute) -> Bool {
        lhs.totalTripDuration < rhs.totalTripDuration
    }
}

import Foundation

struct MultimodalRoute: Identifiable, Codable {
    let id = UUID()
    let station: SubwayStation
    let totalTripDuration: TimeInterval
    let bikeDuration: TimeInterval
    let platformWaitDuration: TimeInterval
    let trainRideDuration: TimeInterval

    // Sortable by total duration
    static func < (lhs: MultimodalRoute, rhs: MultimodalRoute) -> Bool {
        lhs.totalTripDuration < rhs.totalTripDuration
    }
}

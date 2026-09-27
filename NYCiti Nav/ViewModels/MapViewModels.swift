import CoreLocation
import Observation

@MainActor @Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    var coordinate: CLLocationCoordinate2D?
    var message: String?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            message = "Finding your location…"
            manager.requestLocation()
        case .denied, .restricted:
            message = "Enable location access in Settings to preview directions from your position."
        @unknown default: message = "Location is unavailable."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus != .notDetermined { requestLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        coordinate = location.coordinate
        message = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        message = "Could not find your location. Try again or open directions in Apple Maps."
    }
}

import Foundation
import MapKit
import Combine

class SearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = ""
    @Published var completions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]

        // Lock to NYC Metropolitan Area (approximate)
        let nycCenter = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let span = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        completer.region = MKCoordinateRegion(center: nycCenter, span: span)

        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.completer.queryFragment = query
            }
            .store(in: &cancellables)
    }

    func localSearchCompleterDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.completions = completer.results
    }

    func localSearchCompleter(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search Completer Error: \(error.localizedDescription)")
    }
}

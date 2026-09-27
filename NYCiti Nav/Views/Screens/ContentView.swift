import SwiftUI
import MapKit

struct ContentView: View {
    @Environment(StationDataManager.self) private var dataManager
    @State private var routingEngine = RoutingEngine()
    @State private var location = LocationProvider()
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)))
    @State private var selectedStationID: String?
    @State private var destination: MKMapItem?
    @State private var searchError: String?
    @State private var searchID = UUID()
    @State private var activeSearch: MKLocalSearch?
    @State private var navigationTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            if let destination {
                Marker(destination.name ?? "Destination", coordinate: destination.location.coordinate).tint(.red)
            }
            ForEach(dataManager.stations) { station in
                Annotation(station.name, coordinate: station.coordinate, anchor: .bottom) {
                    StationAnnotationView(station: station, isExpanded: selectedStationID == station.id,
                                          onToggle: { selectedStationID = selectedStationID == station.id ? nil : station.id })
                }
            }
            if let route = routingEngine.walkingRoute {
                MapPolyline(route.polyline).stroke(.blue, lineWidth: 6)
            }
        }
        .mapStyle(.standard)
        .safeAreaInset(edge: .top) { searchPanel }
        .safeAreaInset(edge: .bottom) {
            if !isSearchFieldFocused {
                if let destination {
                    RouteSummaryCard(engine: routingEngine, destination: destination.name ?? "Destination",
                                     locationMessage: location.message,
                                     onRetry: { location.requestLocation(); calculateRoute() },
                                     onNavigate: { openTransitDirections(to: destination) })
                } else if let message = location.message {
                    Text(message).font(.caption).padding().background(.regularMaterial)
                }
            }
        }
        .onAppear { location.requestLocation() }
        .onChange(of: location.coordinate?.latitude) { _, _ in calculateRoute() }
        .onChange(of: location.coordinate?.longitude) { _, _ in calculateRoute() }
        .onDisappear {
            navigationTask?.cancel()
            activeSearch?.cancel()
            searchID = UUID()
            routingEngine.reset()
        }
    }

    private var searchPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Where to in NYC?", text: $searchViewModel.searchQuery)
                    .focused($isSearchFieldFocused)
                    .onSubmit { performSearch() }
                if !searchViewModel.searchQuery.isEmpty {
                    Button(action: clearDestination) { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear destination")
                }
            }
            .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
            if let searchError { Text(searchError).font(.caption).padding(8).background(.regularMaterial) }
            if isSearchFieldFocused && !searchViewModel.completions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(searchViewModel.completions, id: \.self) { completion in
                            Button {
                                searchViewModel.searchQuery = completion.title
                                search(MKLocalSearch.Request(completion: completion))
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(completion.title).bold()
                                    Text(completion.subtitle).font(.caption)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                        }
                    }.padding()
                }.frame(maxHeight: 260).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
            }
        }.padding()
    }

    private func performSearch() {
        guard !searchViewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchViewModel.searchQuery
        request.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                                            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
        search(request)
    }

    private func search(_ request: MKLocalSearch.Request) {
        activeSearch?.cancel()
        navigationTask?.cancel()
        routingEngine.reset()
        destination = nil
        searchID = UUID()
        let id = searchID
        searchError = nil
        isSearchFieldFocused = false
        let search = MKLocalSearch(request: request)
        activeSearch = search
        search.start { response, error in
            guard id == searchID else { return }
            guard let item = response?.mapItems.first else {
                searchError = error?.localizedDescription ?? "No destination found. Try a more specific address."
                return
            }
            destination = item
            cameraPosition = .region(MKCoordinateRegion(center: item.location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
            calculateRoute()
        }
    }

    private func calculateRoute() {
        guard let destination, let origin = location.coordinate else { return }
        navigationTask?.cancel()
        navigationTask = Task {
            await routingEngine.calculateRoutes(userLocation: origin, destination: destination.location.coordinate,
                                                availableStations: dataManager.stations)
            guard !Task.isCancelled else { return }
            if let route = routingEngine.walkingRoute {
                let rect = route.polyline.boundingMapRect
                cameraPosition = .rect(rect.insetBy(dx: -max(rect.size.width * 0.15, 300),
                                                   dy: -max(rect.size.height * 0.15, 300)))
            }
        }
    }

    private func clearDestination() {
        activeSearch?.cancel()
        searchID = UUID()
        navigationTask?.cancel()
        routingEngine.reset()
        destination = nil
        searchError = nil
        searchViewModel.searchQuery = ""
    }

    private func openTransitDirections(to destination: MKMapItem) {
        MKMapItem.openMaps(with: [.forCurrentLocation(), destination], launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit
        ])
    }
}

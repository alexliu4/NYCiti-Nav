import SwiftUI
import MapKit

struct ContentView: View {
    @Environment(StationDataManager.self) private var dataManager
    @State private var routingEngine = RoutingEngine()
    @StateObject private var searchViewModel = SearchViewModel()

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedStationID: String?
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var isShowingSearchCompletions = false

    let userLocation = CLLocationCoordinate2D(latitude: 40.7549, longitude: -73.9840)

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                Marker("Current Location", systemImage: "person.fill", coordinate: userLocation)
                    .tint(.blue)

                if let dest = destinationCoordinate {
                    Marker("Destination", systemImage: "flag.fill", coordinate: dest)
                        .tint(.red)
                }

                ForEach(dataManager.stations) { station in
                    if station.lines.count > 1 {
                        Annotation(station.name, coordinate: station.coordinate, anchor: .bottom) {
                            StationAnnotationView(
                                station: station,
                                isExpanded: selectedStationID == station.id,
                                onToggle: { toggleStation(station.id) }
                            )
                        }
                    } else {
                        Marker(station.name, coordinate: station.coordinate)
                            .tint(station.primaryColor)
                    }
                }

                if let selectedRoute = routingEngine.selectedRoute {
                    if let dock = selectedRoute.startDock, let dLat = dock.lat, let dLon = dock.lon {
                        Annotation("Citi Bike Dock", coordinate: CLLocationCoordinate2D(latitude: dLat, longitude: dLon)) {
                            Image(systemName: "bicycle.circle.fill")
                                .font(.title)
                                .foregroundColor(.orange)
                                .background(Color.white.clipShape(Circle()))
                        }
                    }

                    if let polyline = routingEngine.activePolyline {
                        MapPolyline(polyline)
                            .stroke(.blue.opacity(0.6), lineWidth: 5)
                    }
                }
            }
            .mapStyle(.standard)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation {
                    isShowingSearchCompletions = false
                    selectedStationID = nil
                }
            }

            // Bottom UI Stack
            VStack(spacing: 0) {
                if isShowingSearchCompletions && !searchViewModel.completions.isEmpty {
                    List(searchViewModel.completions, id: \.self) { completion in
                        VStack(alignment: .leading) {
                            Text(completion.title)
                                .font(.subheadline)
                            Text(completion.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(Color(.systemBackground))
                        .onTapGesture {
                            selectCompletion(completion)
                        }
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 300)
                    .background(Color(.systemBackground))
                    .cornerRadius(12, corners: [.topLeft, .topRight])
                    .padding(.horizontal)
                    .shadow(radius: 5)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search NYC destinations...", text: $searchViewModel.searchQuery, onEditingChanged: { isEditing in
                        withAnimation {
                            isShowingSearchCompletions = isEditing
                        }
                    })
                    .textFieldStyle(.plain)
                    .onSubmit {
                        performSearch(query: searchViewModel.searchQuery)
                    }

                    if !searchViewModel.searchQuery.isEmpty {
                        Button(action: { searchViewModel.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(isShowingSearchCompletions ? 0 : 12, corners: [.topLeft, .topRight])
                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
                .shadow(radius: 5)
                .padding()

                // Route Summary Card
                if !routingEngine.routes.isEmpty && !isShowingSearchCompletions {
                    RouteSummaryCard(
                        routes: routingEngine.routes,
                        selectedRoute: $routingEngine.selectedRoute,
                        onSelect: { route in
                            routingEngine.selectRoute(route)
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
            }
        }
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        withAnimation {
            isShowingSearchCompletions = false
        }
        searchViewModel.searchQuery = completion.title

        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)

        search.start { response, error in
            guard let mapItem = response?.mapItems.first else { return }
            processSearchResult(mapItem)
        }
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else { return }

        withAnimation {
            isShowingSearchCompletions = false
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        // NYC Region lock
        let nycCenter = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        request.region = MKCoordinateRegion(center: nycCenter, span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let mapItem = response?.mapItems.first else { return }
            processSearchResult(mapItem)
        }
    }

    private func processSearchResult(_ mapItem: MKMapItem) {
        let coordinate = mapItem.placemark.coordinate
        self.destinationCoordinate = coordinate

        Task {
            await routingEngine.calculateRoutes(
                userLocation: userLocation,
                destination: coordinate,
                availableStations: dataManager.stations
            )
            withAnimation {
                cameraPosition = .automatic
            }
        }
    }

    private func toggleStation(_ id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedStationID == id {
                selectedStationID = nil
            } else {
                selectedStationID = id
            }
        }
    }
}

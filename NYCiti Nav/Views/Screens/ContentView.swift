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
        ZStack(alignment: .top) {
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
                isShowingSearchCompletions = false
                selectedStationID = nil
            }

            // Search UI
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search NYC destinations...", text: $searchViewModel.searchQuery, onEditingChanged: { isEditing in
                        isShowingSearchCompletions = isEditing
                    })
                    .textFieldStyle(.plain)
                    if !searchViewModel.searchQuery.isEmpty {
                        Button(action: { searchViewModel.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 5)
                .padding()

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
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .shadow(radius: 5)
                }
            }

            // Route Summary Card
            VStack {
                Spacer()
                if !routingEngine.routes.isEmpty {
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
        isShowingSearchCompletions = false
        searchViewModel.searchQuery = completion.title

        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)

        search.start { response, error in
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else { return }

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

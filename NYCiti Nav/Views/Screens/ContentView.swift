import SwiftUI
import MapKit

struct ContentView: View {
    @Environment(StationDataManager.self) private var dataManager
    @State private var routingEngine = RoutingEngine()
    @StateObject private var searchViewModel = SearchViewModel()

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedStationID: String?
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @FocusState private var isSearchFieldFocused: Bool

    let userLocation = CLLocationCoordinate2D(latitude: 40.7549, longitude: -73.9840)

    var body: some View {
        ZStack(alignment: .top) {
            // 1. Map Layer
            Map(position: $cameraPosition) {
                Marker("Start", systemImage: "person.fill", coordinate: userLocation)
                    .tint(.blue)

                if let dest = destinationCoordinate {
                    Marker("Goal", systemImage: "flag.checkered", coordinate: dest)
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
                        Annotation("Start Bike", coordinate: CLLocationCoordinate2D(latitude: dLat, longitude: dLon)) {
                            Image(systemName: "bicycle.circle.fill")
                                .font(.title)
                                .foregroundColor(.orange)
                                .background(Color.white.clipShape(Circle()))
                        }
                    }

                    if let walkToDock = routingEngine.walkToDockPolyline {
                        MapPolyline(walkToDock)
                            .stroke(.gray.opacity(0.8), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [6, 6]))
                    }

                    if let bikeToStation = routingEngine.bikeToStationPolyline {
                        MapPolyline(bikeToStation)
                            .stroke(.blue.opacity(0.8), lineWidth: 6)
                    }

                    if let trainPoly = routingEngine.trainPolyline {
                        MapPolyline(trainPoly)
                            .stroke(routingEngine.selectedRoute?.station.primaryColor ?? .blue, lineWidth: 8)
                    }

                    if let walkToDest = routingEngine.walkToDestPolyline {
                        MapPolyline(walkToDest)
                            .stroke(.gray.opacity(0.8), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [6, 6]))
                    }
                }
            }
            .mapStyle(.standard)
            .ignoresSafeArea()
            .onTapGesture {
                isSearchFieldFocused = false
                selectedStationID = nil
            }

            // 2. Search & Recommendations Overlay
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Where to?", text: $searchViewModel.searchQuery)
                        .focused($isSearchFieldFocused)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            performSearch(query: searchViewModel.searchQuery)
                        }

                    if !searchViewModel.searchQuery.isEmpty {
                        Button(action: { searchViewModel.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(15)
                .shadow(radius: 5)
                .padding()

                // Recommendations / Completions
                if isSearchFieldFocused && !searchViewModel.completions.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            ForEach(searchViewModel.completions, id: \.self) { completion in
                                Button {
                                    selectCompletion(completion)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(completion.title).font(.subheadline).bold()
                                        Text(completion.subtitle).font(.caption).foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                        .padding()
                    }
                    .background(.thinMaterial)
                    .cornerRadius(15)
                    .padding(.horizontal)
                    .frame(maxHeight: 350)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .offset(y: isSearchFieldFocused ? 0 : UIScreen.main.bounds.height - 200)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isSearchFieldFocused)

            // 3. Navigation / Route Summary Card
            if !isSearchFieldFocused && !routingEngine.routes.isEmpty {
                VStack {
                    Spacer()
                    RouteSummaryCard(
                        routes: routingEngine.routes,
                        selectedRoute: $routingEngine.selectedRoute,
                        onSelect: { route in
                            routingEngine.selectRoute(route)
                        }
                    )
                }
                .ignoresSafeArea()
                .transition(.move(edge: .bottom))
            }
        }
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        searchViewModel.searchQuery = completion.title
        isSearchFieldFocused = false

        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let mapItem = response?.mapItems.first else { return }
            initiateNavigation(to: mapItem)
        }
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else { return }
        isSearchFieldFocused = false

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let nycCenter = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        request.region = MKCoordinateRegion(center: nycCenter, span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let mapItem = response?.mapItems.first else { return }
            initiateNavigation(to: mapItem)
        }
    }

    private func initiateNavigation(to item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        self.destinationCoordinate = coordinate

        Task {
            // Trigger calculation
            await routingEngine.calculateRoutes(
                userLocation: userLocation,
                destination: coordinate,
                availableStations: dataManager.stations
            )

            // Zoom to fit the entire trip
            await MainActor.run {
                withAnimation {
                    fitMapToRoute()
                }
            }
        }
    }

    private func fitMapToRoute() {
        guard let dest = destinationCoordinate else { return }
        let points = [userLocation, dest]
        let rect = points.reduce(MKMapRect.null) { rect, coord in
            let point = MKMapPoint(coord)
            return rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0.1, height: 0.1)))
        }
        // Simplified fit: use automatic for now as it handles dynamic items well
        cameraPosition = .automatic
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

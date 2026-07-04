import SwiftUI
import MapKit

struct ContentView: View {
    @Environment(StationDataManager.self) private var dataManager
    @State private var routingEngine = RoutingEngine()

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedStationID: String?

    // Mock user location in Bryant Park for demonstration
    let userLocation = CLLocationCoordinate2D(latitude: 40.7549, longitude: -73.9840)

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                // User Location Marker
                Marker("Current Location", systemImage: "person.fill", coordinate: userLocation)
                    .tint(.blue)

                // Show all stations
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

                // Route Specific Components
                if let selectedRoute = routingEngine.selectedRoute {
                    // Citi Bike Dock Annotation
                    if let dock = selectedRoute.startDock, let dLat = dock.lat, let dLon = dock.lon {
                        Annotation("Citi Bike Dock", coordinate: CLLocationCoordinate2D(latitude: dLat, longitude: dLon)) {
                            Image(systemName: "bicycle.circle.fill")
                                .font(.title)
                                .foregroundColor(.orange)
                                .background(Color.white.clipShape(Circle()))
                        }
                    }

                    // Destination Station Marker (Highlighted)
                    Marker(selectedRoute.station.name, systemImage: "tram.fill", coordinate: selectedRoute.station.coordinate)
                        .tint(.green)

                    // Route Polyline
                    if let polyline = routingEngine.activePolyline {
                        MapPolyline(polyline)
                            .stroke(.blue.opacity(0.6), lineWidth: 5)
                    }
                }
            }
            .mapStyle(.standard)

            // Route Summary Card
            if !routingEngine.routes.isEmpty {
                RouteSummaryCard(
                    routes: routingEngine.routes,
                    selectedRoute: $routingEngine.selectedRoute,
                    onSelect: { route in
                        routingEngine.selectRoute(route)
                        withAnimation {
                            cameraPosition = .automatic
                        }
                    }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .ignoresSafeArea()
        .task {
            await routingEngine.calculateRoutes(userLocation: userLocation, availableStations: dataManager.stations)
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

#Preview {
    let manager = StationDataManager()
    ContentView()
        .environment(manager)
}

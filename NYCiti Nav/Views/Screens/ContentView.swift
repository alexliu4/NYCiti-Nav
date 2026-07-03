import SwiftUI
import MapKit

struct ContentView: View {
    @Environment(StationDataManager.self) private var dataManager

    // Initial camera position centered on Bryant Park
    // Future: Center at user's current location
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 40.7549, longitude: -73.9840),
            distance: 5000
        )
    )

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(dataManager.stations.indices, id: \.self) { index in
                let station = dataManager.stations[index]
                let label = "\(station.name) (\(station.lines.joined(separator: ", ")))"

                // Alternate between Marker and Annotation (half and half)
                if index % 2 == 0 {
                    Marker(label, coordinate: station.coordinate)
                        .tint(station.primaryColor)
                } else {
                    Annotation(station.name, coordinate: station.coordinate) {
                        StationAnnotationView(station: station)
                    }
                }
            }
        }
        .mapStyle(.standard)
        .ignoresSafeArea()
    }
}

struct StationAnnotationView: View {
    let station: SubwayStation
    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 0) {
            if showDetails {
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name)
                        .font(.caption)
                        .bold()
                    Text("Lines: \(station.lines.joined(separator: ", "))")
                        .font(.system(size: 10))
                }
                .padding(8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 4)
                .transition(.scale.combined(with: .opacity))
            }

            Image(systemName: "mappin.circle.fill")
                .font(.title)
                .foregroundColor(station.primaryColor)
                .background(Color.white.clipShape(Circle()))
                .onTapGesture {
                    withAnimation(.spring()) {
                        showDetails.toggle()
                    }
                }
        }
    }
}

#Preview {
    let manager = StationDataManager()
    ContentView()
        .environment(manager)
}

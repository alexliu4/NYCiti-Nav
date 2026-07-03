import SwiftUI
import MapKit

struct ContentView: View {
    @Environment(StationDataManager.self) private var dataManager

    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 40.7549, longitude: -73.9840),
            distance: 5000
        )
    )

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(dataManager.stations) { station in
                if station.lines.count > 1 {
                    Annotation(station.name, coordinate: station.coordinate) {
                        StationAnnotationView(station: station)
                    }
                } else {
                    let label = "\(station.name) (\(station.lines.first ?? ""))"
                    Marker(label, coordinate: station.coordinate)
                        .tint(station.primaryColor)
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
        VStack(spacing: 4) {
            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text(station.name)
                        .font(.subheadline)
                        .bold()
                        .fixedSize(horizontal: false, vertical: true)

                    // Simple grid for lines to avoid complexity of custom FlowLayout
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 22))], spacing: 4) {
                        ForEach(station.lines, id: \.self) { line in
                            Text(line)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(SubwayStation.color(for: line))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4))
                .frame(width: 160)
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showDetails.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(station.primaryColor)
                        .frame(width: 32, height: 32)
                    Image(systemName: "tram.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                }
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 2)
            }
            .buttonStyle(.plain)
        }
        .zIndex(showDetails ? 1 : 0)
    }
}

#Preview {
    let manager = StationDataManager()
    ContentView()
        .environment(manager)
}

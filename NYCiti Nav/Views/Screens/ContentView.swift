import SwiftUI
import MapKit

struct ContentView: View {
    @Environment(StationDataManager.self) private var dataManager

    // Initial camera position centered on Bryant Park
    // Future: Center at user's current location (comment for the future)
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 40.7549, longitude: -73.9840),
            distance: 5000
        )
    )

    @State private var selectedStationID: String?

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(dataManager.stations) { station in
                if station.lines.count > 1 {
                    // Use anchor .bottom to keep the base pin at the coordinate
                    Annotation(station.name, coordinate: station.coordinate, anchor: .bottom) {
                        StationAnnotationView(
                            station: station,
                            isExpanded: selectedStationID == station.id,
                            onToggle: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if selectedStationID == station.id {
                                        selectedStationID = nil
                                    } else {
                                        selectedStationID = station.id
                                    }
                                }
                            }
                        )
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
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(station.name)
                        .font(.subheadline)
                        .bold()
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 22))], spacing: 4) {
                        ForEach(station.sortedLines, id: \.self) { line in
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

            // The pin icon - this remains at the bottom of the VStack
            Button(action: onToggle) {
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
        // Since Annotation uses anchor: .bottom, the bottom of this VStack (the pin)
        // will stay exactly on the coordinate, and the popover will expand upwards.
        .zIndex(isExpanded ? 1 : 0)
    }
}

#Preview {
    let manager = StationDataManager()
    ContentView()
        .environment(manager)
}

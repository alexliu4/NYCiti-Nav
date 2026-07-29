import SwiftUI

struct RouteSummaryCard: View {
    let routes: [MultimodalRoute]
    @Binding var selectedRoute: MultimodalRoute?
    let onSelect: (MultimodalRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optimal Journeys")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(routes) { route in
                        RouteOptionView(route: route, isSelected: selectedRoute?.id == route.id)
                            .onTapGesture {
                                onSelect(route)
                            }
                    }
                }
                .padding(.horizontal)
            }

            if let selected = selectedRoute {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    Text("Selected: \(selected.station.name)")
                        .font(.subheadline)
                        .bold()

                    HStack {
                        InstructionItem(icon: "bicycle", duration: selected.bikeDuration, label: "Bike")
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        InstructionItem(icon: "clock", duration: selected.platformWaitDuration, label: "Wait")
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        InstructionItem(icon: "tram.fill", duration: selected.trainRideDuration, label: "Train")
                    }

                    Text("Total: \(Int(selected.totalTripDuration / 60)) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(radius: 10)
    }
}

struct RouteOptionView: View {
    let route: MultimodalRoute
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(Int(route.totalTripDuration / 60)) min")
                .font(.title3)
                .bold()
            Text(route.station.name)
                .font(.caption)
                .lineLimit(1)
        }
        .padding()
        .frame(width: 120)
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct InstructionItem: View {
    let icon: String
    let duration: TimeInterval
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
            Text("\(Int(duration / 60))m")
                .font(.caption2)
                .bold()
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

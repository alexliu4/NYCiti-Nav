import SwiftUI

struct RouteStep: Identifiable {
    let id = UUID()
    let icon: String
    let instruction: String
    let duration: TimeInterval
}

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

                    HStack {
                        Text("Selected: \(selected.station.name)")
                            .font(.subheadline)
                            .bold()
                        Spacer()
                        Text("Total: \(Int(selected.totalTripDuration / 60)) min")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.blue)
                    }

                    HStack {
                        if selected.walkToDockDuration > 0 {
                            InstructionItem(icon: "figure.walk", duration: selected.walkToDockDuration, label: "Walk")
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        }

                        InstructionItem(icon: "bicycle", duration: selected.bikeDuration, label: "Bike")
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        InstructionItem(icon: "clock", duration: selected.platformWaitDuration, label: "Wait")
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        InstructionItem(icon: "tram.fill", duration: selected.trainRideDuration, label: "Train")

                        if selected.walkToDestinationDuration > 0 {
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                            InstructionItem(icon: "figure.walk", duration: selected.walkToDestinationDuration, label: "Walk")
                        }
                    }
                    .padding(.vertical, 4)

                    Divider()

                    Text("Route Directions")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(generateSteps(for: selected)) { step in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: step.icon)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.blue)
                                        .frame(width: 24, height: 24)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(step.instruction)
                                            .font(.footnote)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text("\(Int(max(1, step.duration / 60))) min")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 160)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(radius: 10)
    }

    private func generateSteps(for route: MultimodalRoute) -> [RouteStep] {
        var steps: [RouteStep] = []

        // 1. Walk to Dock (if applicable)
        if route.walkToDockDuration > 0 {
            steps.append(RouteStep(
                icon: "figure.walk",
                instruction: "Walk to the nearest Citi Bike dock.",
                duration: route.walkToDockDuration
            ))
        }

        // 2. Bike to Station
        let bikeStationName = route.station.name
        if route.startDock != nil {
            steps.append(RouteStep(
                icon: "bicycle",
                instruction: "Unlock a Citi Bike and ride to \(bikeStationName) subway station.",
                duration: route.bikeDuration
            ))
        } else {
            steps.append(RouteStep(
                icon: "figure.walk",
                instruction: "Walk directly to \(bikeStationName) subway station.",
                duration: route.bikeDuration
            ))
        }

        // 3. Platform wait
        let linesStr = route.station.lines.joined(separator: ", ")
        steps.append(RouteStep(
            icon: "clock",
            instruction: "Enter the station and wait for train (Lines: \(linesStr)).",
            duration: route.platformWaitDuration
        ))

        // 4. Subway ride to destination station
        if let destStation = route.destinationStation {
            if route.station.id != destStation.id {
                steps.append(RouteStep(
                    icon: "tram.fill",
                    instruction: "Ride the train from \(bikeStationName) to \(destStation.name).",
                    duration: route.trainRideDuration
                ))
            }

            // 5. Walk to destination
            if route.walkToDestinationDuration > 0 {
                steps.append(RouteStep(
                    icon: "figure.walk",
                    instruction: "Exit at \(destStation.name) and walk to your destination.",
                    duration: route.walkToDestinationDuration
                ))
            }
        } else {
            steps.append(RouteStep(
                icon: "tram.fill",
                instruction: "Ride the train to your destination station.",
                duration: route.trainRideDuration
            ))
        }

        return steps
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
            Text("\(Int(max(1, duration / 60)))m")
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

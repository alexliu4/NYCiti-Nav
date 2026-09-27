import SwiftUI
import MapKit

struct RouteSummaryCard: View {
    let engine: RoutingEngine
    let destination: String
    let locationMessage: String?
    let onRetry: () -> Void
    let onNavigate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(destination).font(.headline).lineLimit(2)
            Button(action: onNavigate) {
                Label("Transit directions in Apple Maps", systemImage: "tram.fill")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent)
            if engine.isLoading { ProgressView("Finding walking directions…") }
            if let route = engine.walkingRoute {
                Label("Walk · \(Int(ceil(route.expectedTravelTime / 60))) min", systemImage: "figure.walk")
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(route.steps.enumerated()), id: \.offset) { _, step in
                            if !step.instructions.isEmpty { Text(step.instructions).font(.caption) }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 110)
            }
            if let message = engine.errorMessage ?? locationMessage {
                Text(message).font(.caption)
                Button("Try again", action: onRetry)
            }
            if let message = engine.transitMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            } else if let data = engine.transitData {
                Text("Live service data loaded for \(data.subwayTimes.count) subway stops. Transit itineraries open in Apple Maps.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
}

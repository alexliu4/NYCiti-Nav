import SwiftUI

struct StationAnnotationView: View {
    let station: SubwayStation
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
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
        .zIndex(isExpanded ? 1 : 0)
    }
}

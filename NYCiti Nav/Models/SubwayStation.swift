import Foundation
import CoreLocation
import SwiftUI

struct SubwayStation: Codable, Identifiable {
    let id: String
    let name: String
    let lines: [String]
    let lat: Double
    let lon: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var primaryColor: Color {
        if lines.count > 1 {
            return .gray // Hub color
        } else if let firstLine = lines.first {
            return SubwayStation.color(for: firstLine)
        }
        return .blue
    }

    /// Returns the subway lines sorted by canonical MTA groupings and colors
    var sortedLines: [String] {
        lines.sorted { lineA, lineB in
            let rankA = SubwayStation.sortRank(for: lineA)
            let rankB = SubwayStation.sortRank(for: lineB)

            if rankA != rankB {
                return rankA < rankB
            }
            return lineA < lineB
        }
    }

    /// Provides a numerical rank for sorting lines by their MTA groups/colors
    private static func sortRank(for line: String) -> Int {
        switch line.uppercased() {
        case "1", "2", "3": return 1 // Red
        case "4", "5", "6": return 2 // Green
        case "7":           return 3 // Purple
        case "A", "C", "E": return 4 // Blue
        case "B", "D", "F", "M": return 5 // Orange
        case "G":           return 6 // Lime
        case "J", "Z":      return 7 // Brown
        case "L":           return 8 // Gray
        case "N", "Q", "R", "W": return 9 // Yellow
        case "S":           return 10 // Dark Gray
        default:            return 100
        }
    }

    static func color(for line: String) -> Color {
        switch line.uppercased() {
        case "1", "2", "3":
            return Color(red: 238/255, green: 53/255, blue: 46/255)
        case "4", "5", "6":
            return Color(red: 0/255, green: 147/255, blue: 60/255)
        case "7":
            return Color(red: 185/255, green: 51/255, blue: 173/255)
        case "A", "C", "E":
            return Color(red: 0/255, green: 57/255, blue: 166/255)
        case "B", "D", "F", "M":
            return Color(red: 255/255, green: 102/255, blue: 0/255)
        case "G":
            return Color(red: 108/255, green: 190/255, blue: 69/255)
        case "J", "Z":
            return Color(red: 153/255, green: 102/255, blue: 51/255)
        case "L":
            return Color(red: 167/255, green: 169/255, blue: 172/255)
        case "N", "Q", "R", "W":
            return Color(red: 252/255, green: 204/255, blue: 10/255)
        case "S":
            return Color(red: 128/255, green: 129/255, blue: 131/255)
        default:
            return .gray
        }
    }
}

import Foundation

enum Secrets {
    static var apiKey: String {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let value = plist["AppAPIKey"] as? String else { return "" }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import Foundation

enum Secrets {
    static var apiKey: String {
        guard let filePath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: filePath),
              let value = plist["AppAPIKey"] as? String else {
            fatalError("Secrets.plist or AppAPIKey missing")
        }
        return value
    }
}

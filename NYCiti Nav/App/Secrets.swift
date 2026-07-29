import Foundation

enum Secrets {
    // A salt used for obfuscation
    private static let salt = "NYCitiNavSalt2026"

    // The obfuscated API key (Base64 encoded XOR bytes)
    // To generate this, use Obfuscator.obfuscate("YOUR_KEY", salt: salt)
    private static let obfuscatedKeyBase64 = "GhgXFxYWFxYXFhcWFxYXFhcWFxYXFhc="

    static var apiKey: String {
        // First try to load from Secrets.plist (for local development)
        if let filePath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: filePath),
           let value = plist["AppAPIKey"] as? String {
            return value
        }

        // Fallback to obfuscated hardcoded key (for production/distribution)
        guard let data = Data(base64Encoded: obfuscatedKeyBase64) else {
            fatalError("Invalid obfuscated key format")
        }

        let bytes = [UInt8](data)
        return Obfuscator.reveal(bytes, salt: salt)
    }
}

import Foundation

struct Obfuscator {
    /// Basic XOR obfuscation
    static func reveal(_ obfuscated: [UInt8], salt: String) -> String {
        let saltBytes = Array(salt.utf8)
        var decrypted = [UInt8]()

        for (index, byte) in obfuscated.enumerated() {
            decrypted.append(byte ^ saltBytes[index % saltBytes.count])
        }

        return String(bytes: decrypted, encoding: .utf8) ?? ""
    }

    /// Utility to generate obfuscated bytes for the developer (not used by the app directly)
    static func obfuscate(_ string: String, salt: String) -> [UInt8] {
        let stringBytes = Array(string.utf8)
        let saltBytes = Array(salt.utf8)
        var encrypted = [UInt8]()

        for (index, byte) in stringBytes.enumerated() {
            encrypted.append(byte ^ saltBytes[index % saltBytes.count])
        }

        return encrypted
    }
}

import Foundation

class Keys: Codable {
    var keychainEncryptionKey: String?
    
    init(keychainEncryptionKey: String? = "") {
        self.keychainEncryptionKey = keychainEncryptionKey
    }
}

import Foundation

struct EncryptedAuthRequest: Codable {
    var encryptedObject: String
    
    func requestEncryptedAuthRequestObject() -> EncryptedAuthRequest {
        return EncryptedAuthRequest(encryptedObject: self.encryptedObject)
    }
}

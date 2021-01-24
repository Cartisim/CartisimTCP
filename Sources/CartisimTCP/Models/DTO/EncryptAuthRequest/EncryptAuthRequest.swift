import Foundation

struct EncryptedRequest: Codable {
    var encryptedObject: String
    
    func requestEncryptedAuthRequestObject() -> EncryptedRequest {
        return EncryptedRequest(encryptedObject: self.encryptedObject)
    }
}

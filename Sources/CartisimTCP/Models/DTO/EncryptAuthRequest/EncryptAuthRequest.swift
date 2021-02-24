import Foundation

struct EncryptedAuthRequest: Codable {
    var encryptedObject: String
    
    func requestEncryptedAuthRequestObject() -> EncryptedAuthRequest {
        return EncryptedAuthRequest(encryptedObject: self.encryptedObject)
    }
}


struct RefreshToken: Codable {
    var refreshToken: String
    
    func requestRefreshTokenObject() -> RefreshToken {
        return RefreshToken(refreshToken: self.refreshToken)
    }
}

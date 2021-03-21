#if os(macOS)
import CryptoKit
#else
import Crypto
#endif
import Foundation

public class CartisimCrypto: NSObject {
    
    static func userInfoKey(_ key: String) -> SymmetricKey {
        let hash = SHA256.hash(data: key.data(using: .utf8)!)
        let hashString = hash.map { String(format: "%02hhx", $0)}.joined()
        let subString = String(hashString.prefix(32))
        let keyData = subString.data(using: .utf8)!
        return SymmetricKey(data: keyData)
    }
    
    static func encryptCodableObject<T: Codable>(_ object: T, usingKey key: SymmetricKey) throws -> String {
        let encoder = JSONEncoder()
        let userData = try encoder.encode(object)
        let encryptedData = try AES.GCM.seal(userData, using: key)
        return encryptedData.combined!.base64EncodedString()
    }
    
    static func decryptStringToCodableObject<T: Codable>(_ type: T.Type, from string: String, usingKey key: SymmetricKey) throws -> T {
        let data = Data(base64Encoded: string)!
        let box = try AES.GCM.SealedBox(combined: data)
        let decryptData = try AES.GCM.open(box, using: key)
        let decoder = JSONDecoder()
        let object = try decoder.decode(type, from: decryptData)
        return object
    }
    
    static func encryptableBody<T: Codable>(body: T) -> EncryptedObject {
        let key = CartisimCrypto.userInfoKey(KeyData.shared.keychainEncryptionKey)
        let bodyData = try? CartisimCrypto.encryptCodableObject(body, usingKey: key)
        let encryptedObjectString = EncryptedObject(encryptedObjectString: bodyData!)
        return encryptedObjectString
    }
    
    static func decryptableResponse<T: Codable>(_ body: T.Type, string: String) -> T? {
        let key = CartisimCrypto.userInfoKey(KeyData.shared.keychainEncryptionKey)
        do {
            let object = try CartisimCrypto.decryptStringToCodableObject(body, from: string, usingKey: key)
            return object
        } catch {
            print(error)
        }
        return nil
    }
}

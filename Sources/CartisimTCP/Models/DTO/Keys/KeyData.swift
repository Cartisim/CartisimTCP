import Foundation

struct KeyData {
    static var shared = KeyData()
    
    fileprivate var _keychainEncryptionKey: String = ""
    
    var keychainEncryptionKey: String {
        get {
            return _keychainEncryptionKey
        }
        set {
            _keychainEncryptionKey = newValue
        }
    }
}

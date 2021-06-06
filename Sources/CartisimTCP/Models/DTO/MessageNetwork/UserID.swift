


public struct UserID: Hashable, CustomStringConvertible {
    
    public let id: DMIdentifier
    public let user: String?
    public let host: String?
    
    @inlinable
    public init(id: DMIdentifier, user: String? = nil, host: String? = nil) {
        self.id = id
        self.user = user
        self.host = host
    }
    
    @inlinable
    public init?(_ s: String) {
        if let atIdx = s.firstIndex(of: "@") {
            let hs = s.index(after: atIdx)
            self.host = String(s[hs..<s.endIndex])
            
            let idString: String
            if let exIdx = s.firstIndex(of: "!") {
                let hs = s.index(after: exIdx)
                self.user = String(s[hs..<atIdx])
                
                idString = String(s[s.startIndex..<exIdx])
            } else {
                self.user = nil
                idString = String(s[s.startIndex..<atIdx])
            }
            guard let id = DMIdentifier(idString) else { return nil }
            self.id = id
        } else {
            guard let id = DMIdentifier(s) else { return nil }
            self.id = id
            self.user = nil
            self.host = nil
        }
    }
    
    @inlinable
    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
    
    @inlinable
    public static func ==(lhs: UserID, rhs: UserID) -> Bool {
        return lhs.id == rhs.id && lhs.user == rhs.user && lhs.host == rhs.host
    }
    
    @inlinable
    public var stringValue: String {
        var ms = "\(id)"
        if let host = host {
            if let user = user {
                ms += "!\(user)"
            }
            ms += "@\(host)"
        }
        return ms
    }
    
    @inlinable
    public var description: String { return stringValue }
}

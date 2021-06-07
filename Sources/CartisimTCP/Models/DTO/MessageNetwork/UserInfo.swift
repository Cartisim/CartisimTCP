

public struct UserInfo: Equatable {
    
    public let username:   String
    public let usermask:   UserMode?
    public let hostname:   String?
    public let servername: String?
    public let realname:   String
    
    @inlinable
    public init(username: String, usermask: UserMode, realname: String) {
        self.username   = username
        self.usermask   = usermask
        self.realname   = realname
        self.hostname   = nil
        self.servername = nil
    }
    
    @inlinable
    public init(username: String, hostname: String, servername: String, realname: String) {
        self.username   = username
        self.hostname   = hostname
        self.servername = servername
        self.realname   = realname
        self.usermask   = nil
    }
    
    @inlinable
    public static func ==(lhs: UserInfo, rhs: UserInfo) -> Bool {
        if lhs.username   != rhs.username { return false }
        if lhs.realname   != rhs.realname { return false }
        if lhs.usermask   != rhs.usermask { return false }
        if lhs.servername != rhs.servername { return false }
        if lhs.hostname   != rhs.hostname   { return false }
        return true
    }
}

extension UserInfo: CustomStringConvertible {
    
    @inlinable
    public var description: String {
        var ms = "<UserInfo: \(username)>"
        if let v = usermask     { ms += " mask=\(v)" }
        if let v = hostname     { ms += " mask=\(v)" }
        if let v = servername   { ms += " mask=\(v)" }
        ms += " '\(realname)"
        ms += ">"
        return ms
    }
}

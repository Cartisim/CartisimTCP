

public struct UserMode: OptionSet {
    public let rawValue: UInt16
    
    @inlinable
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    
    public static let receivesWallOps       = UserMode(rawValue: 1 << 2)
    public static let invisable             = UserMode(rawValue: 1 << 3)
     
    public static let away                  = UserMode(rawValue: 1 << 4)
    public static let restrictedConnection  = UserMode(rawValue: 1 << 5)
    public static let `operator`            = UserMode(rawValue: 1 << 6)
    public static let localOperator         = UserMode(rawValue: 1 << 7)
    public static let receivesServerNotices = UserMode(rawValue: 1 << 8)
    
    //Freenode
    public static let ignoreUnknown         = UserMode(rawValue: 1 << 9)
    public static let disableForwarding     = UserMode(rawValue: 1 << 10)
    public static let blockUnidentified     = UserMode(rawValue: 1 << 11)
    public static let connectedSecurely     = UserMode(rawValue: 1 << 12)
 
    //UnrealIRCd
    public static let hideHostname          = UserMode(rawValue: 1 << 13)
    
    @inlinable
    public var maskValue: UInt16 { return rawValue }
    
    @inlinable
    public init?(_ string: String) {
        var mask: UInt16 = 0
        for c in string {
            switch c {
            case "w": mask += UserMode.receivesWallOps       .rawValue
            case "i": mask += UserMode.invisable             .rawValue
            case "a": mask += UserMode.away                  .rawValue
            case "r": mask += UserMode.restrictedConnection  .rawValue
            case "o": mask += UserMode.operator              .rawValue
            case "O": mask += UserMode.localOperator         .rawValue
            case "s": mask += UserMode.receivesServerNotices .rawValue
            case "g": mask += UserMode.ignoreUnknown         .rawValue
            case "Q": mask += UserMode.disableForwarding     .rawValue
            case "R": mask += UserMode.blockUnidentified     .rawValue
            case "Z": mask += UserMode.connectedSecurely     .rawValue
            case "x": mask += UserMode.hideHostname          .rawValue
            default: return nil
            }
        }
        self.init(rawValue: mask)
    }
    
    @inlinable
    public var stringValue: String {
        var mode = ""
        mode.reserveCapacity(8)
        if contains(.receivesWallOps)           { mode += "w" }
        if contains(.invisable)                 { mode += "i" }
        if contains(.away)                      { mode += "a" }
        if contains(.restrictedConnection)      { mode += "r" }
        if contains(.operator)                  { mode += "o" }
        if contains(.localOperator)             { mode += "O" }
        if contains(.receivesServerNotices)     { mode += "s" }
        if contains(.ignoreUnknown)             { mode += "g" }
        if contains(.disableForwarding)         { mode += "Q" }
        if contains(.blockUnidentified)         { mode += "R" }
        if contains(.connectedSecurely)         { mode += "Z" }
        if contains(.hideHostname)              { mode += "x" }
        return mode
    }
    
}

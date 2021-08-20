
public struct ChannelMode: OptionSet {
    public let rawValue: UInt16
    
    
    @inlinable
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    
    public static let channelOperator = ChannelMode(rawValue: 1 << 0)
    public static let `private` = ChannelMode(rawValue: 1 << 1)
    public static let secret = ChannelMode(rawValue: 1 << 2)
    public static let inviteOnly = ChannelMode(rawValue: 1 << 3)
    public static let topicOnlyByOperator = ChannelMode(rawValue: 1 << 4)
    public static let noOutsideClients = ChannelMode(rawValue: 1 << 5)
    public static let moderated = ChannelMode(rawValue: 1 << 6)
    public static let userLimit = ChannelMode(rawValue: 1 << 7)
    public static let banMask = ChannelMode(rawValue: 1 << 8)
    public static let speakControl = ChannelMode(rawValue: 1 << 9)
    public static let password = ChannelMode(rawValue: 1 << 10)
    
    @inlinable
    public init?(_ string: String) {
        var mask: UInt16 = 0
        for c in string {
            switch c {
            case "o" : mask += ChannelMode.channelOperator.rawValue
            case "p" : mask += ChannelMode.`private`.rawValue
            case "s" : mask += ChannelMode.secret.rawValue
            case "i" : mask += ChannelMode.inviteOnly.rawValue
            case "t" : mask += ChannelMode.topicOnlyByOperator.rawValue
            case "n" : mask += ChannelMode.noOutsideClients.rawValue
            case "m" : mask += ChannelMode.moderated.rawValue
            case "l" : mask += ChannelMode.userLimit.rawValue
            case "b" : mask += ChannelMode.banMask.rawValue
            case "v" : mask += ChannelMode.speakControl.rawValue
            case "k" : mask += ChannelMode.password.rawValue
            default  :
                return nil
            }
        }
        self.init(rawValue: mask)
    }
    
    @inlinable
    public var stringValue: String {
        var mode = ""
        if contains(.channelOperator)      { mode += "o" }
        if contains(.`private`)            { mode += "p" }
        if contains(.secret)               { mode += "s" }
        if contains(.inviteOnly)           { mode += "i" }
        if contains(.topicOnlyByOperator)  { mode += "t" }
        if contains(.noOutsideClients)      { mode += "n" }
        if contains(.moderated)            { mode += "m" }
        if contains(.userLimit)            { mode += "l" }
        if contains(.banMask)              { mode += "b" }
        if contains(.speakControl)         { mode += "v" }
        if contains(.password)             { mode += "k" }
        return mode
    }
}

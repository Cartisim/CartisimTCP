import Foundation


public enum MessageRecipient: Hashable {
    case channel (ChannelName)
    case dm (DMIdentifier)
    case all
    
    @inlinable
    public func hash(into hasher: inout Hasher) {
      switch self {
        case .channel (let name): return name.hash(into: &hasher)
        case .dm      (let name): return name.hash(into: &hasher)
        case .all:                return 42.hash(into: &hasher)
      }
    }
    
    @inlinable
    public static func ==(lhs: MessageRecipient, rhs: MessageRecipient)
                    -> Bool
    {
      switch ( lhs, rhs ) {
        case ( .all,               .all ):              return true
        case ( .channel (let lhs), .channel (let rhs)): return lhs == rhs
        case ( .dm(let lhs),       .dm(let rhs)):       return lhs == rhs
        default: return false
      }
    }

}

public extension MessageRecipient {

    @inlinable
    init?(_ s: String) {
        if s == "*"                                           { self = .all }
        else if let directMessageIdentifier = DMIdentifier(s) { self = .dm(directMessageIdentifier) }
        else if let channelName             = ChannelName(s)  { self = .channel(channelName) }
        else { return nil }
    }
    
    @inlinable
    var stringValue: String {
        switch self {
        case .channel(let channelName):         return channelName.stringValue
        case .dm(let directMessageIdentifier):  return directMessageIdentifier.stringValue
        case .all:                              return "*"
        }
    }
}

extension MessageRecipient: CustomStringConvertible {
    
    @inlinable
    public var description: String {
        switch self {
        case .channel(let channelName):         return channelName.description
        case .dm(let directMessageIdentifier):  return directMessageIdentifier.description
        case .all:                              return "<MessageRecipient: *>"
        }
    }
}

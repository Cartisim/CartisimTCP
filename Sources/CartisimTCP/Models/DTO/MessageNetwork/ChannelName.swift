import Foundation

public struct ChannelName: Hashable, CustomStringConvertible {
    
    public typealias StringLiteralType = String
    
    @usableFromInline let storage: String
    @usableFromInline let normalized: String
    
    
    @inlinable
    public init?(_ s: String) {
        guard ChannelName.validate(string: s) else {
            return nil
        }
        storage = s
        normalized = s.lowercased()
    }
    
    @inlinable
    public var stringValue: String { return storage }
    
    
    
    @inlinable
    public func hash(into hasher: inout Hasher) {
        normalized.hash(into: &hasher)
    }
    
    @inlinable
    public static func ==(lhs: ChannelName, rhs: ChannelName) -> Bool {
        return lhs.normalized == rhs.normalized
    }
        
    public var description: String { return stringValue }

    ///Here we can validate channelName creation
    @inlinable
    public static func validate(string: String) -> Bool {
        return true
    }
}

import Foundation

public struct DMIdentifier: Hashable, CustomStringConvertible {
    
    public typealias StringLiteralType = String
    
    @usableFromInline let storage: String
    @usableFromInline let normalized: String
    
    public struct ValidationFlags: OptionSet {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue}
        
        public static let none = ValidationFlags([])
    }
    
    @inlinable
    public init?(_ s: String, validationFlags: ValidationFlags = [ .none ]) {
        
        guard DMIdentifier.validate(string: s, validationFlags: validationFlags) else {
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
    public static func ==(lhs: DMIdentifier, rhs: DMIdentifier) -> Bool {
        return lhs.normalized == rhs.normalized
    }

    @inlinable
    public var description: String { return stringValue }
    
    public static func validate(string: String, validationFlags: ValidationFlags) -> Bool {
        return true
    }
    
 
}

import Foundation


struct Message: Codable, CustomStringConvertible {
    
     enum CodingKeys: String, CodingKey {
        case origin, target, command, arguments
    }
    
    @inlinable
    init(origin: String? = nil, target: String? = nil, command: Command) {
        self._storage = _Storage(origin: origin, target: target, command: command)
    }
    
    @inlinable
    var origin: String? {
        set { copyStorageIfNeeded(); _storage.origin = newValue }
        get { return _storage.origin }
    }
    
    @inlinable
    var target: String? {
        set { copyStorageIfNeeded(); _storage.target = newValue }
        get { return _storage.target }
    }
    
    @inlinable
    var command: Command {
        set { copyStorageIfNeeded(); _storage.command = newValue }
        get { return _storage.command }
    }
    
    @inlinable
    var description: String {
        var ms = "<Msg:"
        if let origin = origin { ms += " from=\(origin)" }
        if let target = target { ms += " to=\(target)" }
        ms += ""
        ms += command.description
        ms += ">"
        return ms
    }
    
    //Mark: Internal Storage
    
    @usableFromInline
    class _Storage {
        @usableFromInline var origin: String?
        @usableFromInline var target: String?
        @usableFromInline var command: CommandLine
        
        @usableFromInline
        init(origin: String?, target: String?, command: Command) {
            self.origin = origin
            self.target = target
            self.command = command
        }
    }
    
    @usableFromInline var _storage: _Storage
    
    //MARK: - Codable
    
    @inlinable
    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        let cmd     = try c.decode(String.self, forKey: .command)
        let args    = try c.decodeIfPresent([ String ].self, forKey: .arguments)
        let command = try Command(cmd, arguments: args ?? [])
        
        self.init(origin: try c.decodeIfPresent(String.self, forKey: .origin),
                  target: try c.decodeIfPresent(String.self, forKey: .target),
                  command: command)
    }
    
    @inlinable
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(origin, forKey: .origin)
        try c.encodeIfPresent(target, forKey: .target)
        try c.encode(command.commandAsString, forKey: .command)
        try c.encode(command.arguments, forKey: .arguments)
    }
}

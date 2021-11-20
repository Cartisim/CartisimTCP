//import Logging
//import Foundation
//import NIOIRC
//
//internal class ServerContext {
//    
//    typealias Error = ServerError
//    
//    internal let origin: String
//    internal let logger: Logger
//    internal let created = Date()
//    
//    private var lock = RWLock()
//    private var nickToSession = [ IRCNickName : SessionHandler ]()
//    private var nameToChannel = [ IRCChannelName : ServerChannel]()
//    
//    internal struct ServerInfo {
//        let userCount: Int
//        let invisibleCount: Int
//        let serverCount: Int
//        let operatorCount: Int
//        let channelCount: Int
//    }
//    
//    
//    init(origin: String, logger: Logger) {
//        self.origin = origin
//        self.logger = logger
//        
//        registerDefaultChannels()
//    }
//    
//    internal func registerDefaultChannels() {
//        let defaultChannels = ["#Cartisim"]
//        
//        for channel in defaultChannels {
//            guard let name = IRCChannelName(channel) else {
//                fatalError("invalid channel name: \(channel)")
//            }
//            
//            nameToChannel[name] = ServerChannel(name: name, context: self)
//        }
//    }
//    
//    
//    internal func getServerInfo() -> ServerInfo {
//        lock.lockForReading(); defer {
//            lock.unlock()
//        }
//        let info = ServerInfo(userCount: nickToSession.count, invisibleCount: 0, serverCount: 1, operatorCount: 1, channelCount: nameToChannel.count)
//        return info
//    }
//    
//    internal func getSessions() -> [ SessionHandler ] {
//        lock.lockForReading(); defer {
//            lock.unlock()
//        }
//        return Array(nickToSession.values)
//    }
//    
//    internal func getSessions(in channel: IRCChannelName) -> [ SessionHandler ]? {
//        lock.lockForReading(); defer {
//            lock.unlock()
//        }
//        guard let existingChannel = nameToChannel[channel] else { return nil }
//        return existingChannel.subscribers
//    }
//    
//    internal func getSession(of dmid: IRCNickName) -> SessionHandler? {
//        lock.lockForReading(); defer {
//            lock.unlock()
//        }
//        return nickToSession[dmid]
//    }
//    
//    internal func getNicksOnline() -> [ IRCNickName ] {
//        lock.lockForReading(); defer { lock.unlock() }
//        return Array(nickToSession.keys)
//    }
//    
//    // MARK: - Channels
//    
//    func getChannelMode(_ name: IRCChannelName) -> IRCChannelMode? {
//      lock.lockForReading(); defer { lock.unlock() }
//      return nameToChannel[name]?.mode
//    }
//    
//    func getChannelInfos(_ channels: [ IRCChannelName ]?) -> [ ServerChannel.Info ] {
//      lock.lockForReading(); defer { lock.unlock() }
//      
//      if let channelNames = channels {
//          let channels = channelNames.compactMap({ self.nameToChannel[$0] })
//        return channels.map { $0.getInfo() }
//      }
//      else {
//        return nameToChannel.values.map { $0.getInfo() }
//      }
//    }
//    
//    func joinChannel(_ name: IRCChannelName, session: SessionHandler)
//           -> ServerChannel.Info
//    {
//      lock.lockForWriting(); defer { lock.unlock() }
//      
//      let channel : ServerChannel
//      
//      if let existingChannel = nameToChannel[name] {
//        channel = existingChannel
//      }
//      else {
//        channel = ServerChannel(name: name, context: self)
//        nameToChannel[name] = channel
//        
//        // only works because we happen run in the session thread
//        assert(session.channel?.eventLoop.inEventLoop ?? false,
//               "not running in session eventloop")
//          if let nick = session.nick {
//          channel.operators.insert(nick)
//        }
//      }
//      
//      _ = channel.join(session)
//      
//      return channel.getInfo()
//    }
//    
//    func partChannel(_ name: IRCChannelName, session: SessionHandler) {
//      lock.lockForWriting(); defer { lock.unlock() }
//      guard let existingChannel = nameToChannel[name] else { return }
//      _ = existingChannel.part(session)
//    }
//    
//    
//    // MARK: - DMID handling
//    
//    func renameNick(from oldNick: IRCNickName, to newNick: IRCNickName) throws {
//      guard oldNick != newNick else { return }
//      lock.lockForWriting(); defer { lock.unlock() }
//
//      guard nickToSession[newNick] == nil else {
//        throw Error.nicknameInUse(newNick)
//      }
//
//      guard let session = nickToSession.removeValue(forKey: oldNick) else {
//        throw Error.noSuchNick(oldNick)
//      }
//
//        nickToSession[newNick] = session
//    }
//    
//    func registerSession(_ session: SessionHandler, id: IRCNickName) throws {
//      lock.lockForWriting(); defer { lock.unlock() }
//      
//      guard nickToSession[id] == nil else {
//          throw Error.nicknameInUse(id)
//      }
//        nickToSession[id] = session
//    }
//
//    func unregisterSession(_ session: SessionHandler, nick: IRCNickName)
//           throws
//    {
//      lock.lockForWriting(); defer { lock.unlock() }
//      
//      guard nickToSession[nick] != nil else { throw Error.noSuchNick(nick) }
//      guard nickToSession[nick] === session else {
//        assert(nickToSession[nick] === session,
//               "attempt to unregister nick of different session \(nick)?")
//        return
//      }
//      
//        nickToSession.removeValue(forKey: nick)
//    }
//    
//    
//}
//
//internal typealias ServerError = IRCDispatcherError
//
//extension IRCCommandCode {
//  
//  var errorMessage : String {
//    return errorMap[self] ??  "Unmapped error code \(self.rawValue)"
//  }
//}
//
//fileprivate let errorMap : [ IRCCommandCode : String ] = [
//  .errorUnknownCommand:    "No such command.",
//  .errorNoSuchServer:      "No such server.",
//  .errorNicknameInUse:     "Identity is already in use.",
//  .errorNoSuchNick:        "No such Identifier.",
//  .errorAlreadyRegistered: "You may not reregister.",
//  .errorNotRegistered:     "You have not registered",
//  .errorUsersDontMatch:    "Users don't match",
//  .errorNoSuchChannel:     "No such channel"
//]
//
//
//internal enum ServerDispatcherError : Swift.Error {
//  
//  case doesNotRespondTo(IRCMessage)
//  
//  case identifierInUse(IRCNickName)
//  case noSuchIdentifier   (IRCNickName)
//  case noSuchChannel(IRCChannelName)
//  case alreadyRegistered
//  case notRegistered
//  case cantChangeModeForOtherUsers
//}
//
//final class RWLock {
//  
//  private var lock = pthread_rwlock_t()
//  
//  public init() {
//    pthread_rwlock_init(&lock, nil)
//  }
//  deinit {
//    pthread_rwlock_destroy(&lock)
//  }
//  
//  @inline(__always)
//  func lockForReading() {
//    pthread_rwlock_rdlock(&lock)
//  }
//  
//  @inline(__always)
//  func lockForWriting() {
//    pthread_rwlock_wrlock(&lock)
//  }
//  
//  @inline(__always)
//  func unlock() {
//    pthread_rwlock_unlock(&lock)
//  }
//  
//}
//
//
//internal class ServerChannel {
//  
//  /// When a consumer wants information about a channel, we put it into this
//  /// immutable object and return it.
//    internal struct Info {
//    let name        : IRCChannelName
//    let welcome     : String
//    let operators   : Set<IRCNickName>
//    let subscribers : [ SessionHandler ]
//    let mode        : IRCChannelMode
//  }
//  
//  weak var context : ServerContext?
//    internal let name  : IRCChannelName
//  
//  // Careful: owned and write protected by ServerContext
//  var welcome      : String
//  var operators    = Set<IRCNickName>()
//  var subscribers  = [ SessionHandler ]()
//  var mode         : IRCChannelMode = [ .noOutsideClients,
//                                        .topicOnlyByOperator ]
//
//  // TODO: mode, e.g. can be invite-only (needs a invite list)
//  
//    internal init(name: IRCChannelName, welcome: String? = nil,
//              context: ServerContext)
//  {
//    self.name    = name
//    self.context = context
//    self.welcome = welcome ?? "Welcome to \(name.stringValue)!"
//  }
//  
//  
//  // MARK: - Subscription
//
//  /// Returns an immutable copy of the channel state
//    internal func getInfo() -> Info { // T: r+lock by ctx
//    return Info(name        : name,
//                welcome     : welcome,
//                operators   : operators,
//                subscribers : subscribers,
//                mode        : mode)
//  }
//  
//    internal func join(_ session: SessionHandler) -> Bool { // T: wlock by ctx
//      guard subscribers.firstIndex(where: {$0 === session}) == nil else {
//        return false // already subscribed
//      }
//    
//    subscribers.append(session)
//    return true
//  }
//  
//    internal func part(_ session: SessionHandler) -> Bool { // T: wlock by ctx
//      guard let idx = subscribers.firstIndex(where: {$0 === session}) else {
//        return false // not subscribed
//      }
//    
//    subscribers.remove(at: idx)
//    return true
//  }
//}

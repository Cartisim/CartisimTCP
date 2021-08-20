import Logging
import Foundation

internal class ServerContext {
    
    typealias Error = ServerError
    
    internal let origin: String
    internal let logger: Logger
    internal let created = Date()
    
    private var lock = RWLock()
    private var idToSession = [ DMIdentifier : SessionHandler ]()
    private var nameToChannel = [ ChannelName : ServerChannel]()
    
    
    internal struct ServerInfo {
        let userCount: Int
        let invisibleCount: Int
        let serverCount: Int
        let operatorCount: Int
        let channelCount: Int
    }
    
    
    init(origin: String, logger: Logger) {
        self.origin = origin
        self.logger = logger
        
        registerDefaultChannels()
    }
    
    internal func registerDefaultChannels() {
        let defaultChannels = ["#Cartisim"]
        
        for channel in defaultChannels {
            guard let name = ChannelName(channel) else {
                fatalError("invalid channel name: \(channel)")
            }
            
            nameToChannel[name] = ServerChannel(name: name, context: self)
        }
    }
    
    
    internal func getServerInfo() -> ServerInfo {
        lock.lockForReading(); defer {
            lock.unlock()
        }
        let info = ServerInfo(userCount: idToSession.count, invisibleCount: 0, serverCount: 1, operatorCount: 1, channelCount: nameToChannel.count)
        return info
    }
    
    internal func getSessions() -> [ SessionHandler ] {
        lock.lockForReading(); defer {
            lock.unlock()
        }
        return Array(idToSession.values)
    }
    
    internal func getSessions(in channel: ChannelName) -> [ SessionHandler ]? {
        lock.lockForReading(); defer {
            lock.unlock()
        }
        guard let existingChannel = nameToChannel[channel] else { return nil }
        return existingChannel.subscribers
    }
    
    internal func getSession(of dmid: DMIdentifier) -> SessionHandler? {
        lock.lockForReading(); defer {
            lock.unlock()
        }
        return idToSession[dmid]
    }
    
    internal func getDMIDSOnline() -> [ DMIdentifier ] {
        lock.lockForReading(); defer { lock.unlock() }
        return Array(idToSession.keys)
    }
    
    // MARK: - Channels
    
    func getChannelMode(_ name: ChannelName) -> ChannelMode? {
      lock.lockForReading(); defer { lock.unlock() }
      return nameToChannel[name]?.mode
    }
    
    func getChannelInfos(_ channels: [ ChannelName ]?) -> [ ServerChannel.Info ] {
      lock.lockForReading(); defer { lock.unlock() }
      
      if let channelNames = channels {
        #if swift(>=4.1)
          let channels = channelNames.compactMap({ self.nameToChannel[$0] })
        #else
          let channels = channelNames.flatMap({ self.nameToChannel[$0] })
        #endif
        
        return channels.map { $0.getInfo() }
      }
      else {
        return nameToChannel.values.map { $0.getInfo() }
      }
    }
    
    func joinChannel(_ name: ChannelName, session: SessionHandler)
           -> ServerChannel.Info
    {
      lock.lockForWriting(); defer { lock.unlock() }
      
      let channel : ServerChannel
      
      if let existingChannel = nameToChannel[name] {
        channel = existingChannel
      }
      else {
        channel = ServerChannel(name: name, context: self)
        nameToChannel[name] = channel
        
        // only works because we happen run in the session thread
        assert(session.channel?.eventLoop.inEventLoop ?? false,
               "not running in session eventloop")
          if let dmid = session.id {
          channel.operators.insert(dmid)
        }
      }
      
      _ = channel.join(session)
      
      return channel.getInfo()
    }
    
    func partChannel(_ name: ChannelName, session: SessionHandler) {
      lock.lockForWriting(); defer { lock.unlock() }
      guard let existingChannel = nameToChannel[name] else { return }
      _ = existingChannel.part(session)
    }
    
    
    // MARK: - DMID handling
    
//    func renameDMID(from oldID: DMIdentifier, to newID: DMIdentifer) throws {
//      guard oldNick != newID else { return }
//      lock.lockForWriting(); defer { lock.unlock() }
//
//      guard idToSession[newID] == nil else {
//        throw Error.IdInUse(newID)
//      }
//
//      guard let session = idToSession.removeValue(forKey: oldID) else {
//        throw Error.noSuchDMID(oldID)
//      }
//
//      idToSession[newID] = session
//    }
    
    func registerSession(_ session: SessionHandler, id: DMIdentifier) throws {
      lock.lockForWriting(); defer { lock.unlock() }
      
      guard idToSession[id] == nil else {
          throw Error.identifierInUse(id)
      }
      idToSession[id] = session
    }

    func unregisterSession(_ session: SessionHandler, id: DMIdentifier)
           throws
    {
      lock.lockForWriting(); defer { lock.unlock() }
      
      guard idToSession[id] != nil else { throw Error.noSuchIdentifier(id) }
      guard idToSession[id] === session else {
        assert(idToSession[id] === session,
               "attempt to unregister nick of different session \(id)?")
        return
      }
      
      idToSession.removeValue(forKey: id)
    }
    
    
}

internal typealias ServerError = ServerDispatcherError

extension CommandCode {
  
  var errorMessage : String {
    return errorMap[self] ??  "Unmapped error code \(self.rawValue)"
  }
}

fileprivate let errorMap : [ CommandCode : String ] = [
  .errorUnknownCommand:    "No such command.",
  .errorNoSuchServer:      "No such server.",
  .errorIdentityInUse:     "Identity is already in use.",
  .errorNoSuchDMID:        "No such Identifier.",
  .errorAlreadyRegistered: "You may not reregister.",
  .errorNotRegistered:     "You have not registered",
  .errorUsersDontMatch:    "Users don't match",
  .errorNoSuchChannel:     "No such channel"
]


internal enum ServerDispatcherError : Swift.Error {
  
  case doesNotRespondTo(Message)
  
  case identifierInUse(DMIdentifier)
  case noSuchIdentifier   (DMIdentifier)
  case noSuchChannel(ChannelName)
  case alreadyRegistered
  case notRegistered
  case cantChangeModeForOtherUsers
}

final class RWLock {
  
  private var lock = pthread_rwlock_t()
  
  public init() {
    pthread_rwlock_init(&lock, nil)
  }
  deinit {
    pthread_rwlock_destroy(&lock)
  }
  
  @inline(__always)
  func lockForReading() {
    pthread_rwlock_rdlock(&lock)
  }
  
  @inline(__always)
  func lockForWriting() {
    pthread_rwlock_wrlock(&lock)
  }
  
  @inline(__always)
  func unlock() {
    pthread_rwlock_unlock(&lock)
  }
  
}


internal class ServerChannel {
  
  /// When a consumer wants information about a channel, we put it into this
  /// immutable object and return it.
    internal struct Info {
    let name        : ChannelName
    let welcome     : String
    let operators   : Set<DMIdentifier>
    let subscribers : [ SessionHandler ]
    let mode        : ChannelMode
  }
  
  weak var context : ServerContext?
    internal let name  : ChannelName
  
  // Careful: owned and write protected by ServerContext
  var welcome      : String
  var operators    = Set<DMIdentifier>()
  var subscribers  = [ SessionHandler ]()
  var mode         : ChannelMode = [ .noOutsideClients,
                                        .topicOnlyByOperator ]

  // TODO: mode, e.g. can be invite-only (needs a invite list)
  
    internal init(name: ChannelName, welcome: String? = nil,
              context: ServerContext)
  {
    self.name    = name
    self.context = context
    self.welcome = welcome ?? "Welcome to \(name.stringValue)!"
  }
  
  
  // MARK: - Subscription

  /// Returns an immutable copy of the channel state
    internal func getInfo() -> Info { // T: r+lock by ctx
    return Info(name        : name,
                welcome     : welcome,
                operators   : operators,
                subscribers : subscribers,
                mode        : mode)
  }
  
    internal func join(_ session: SessionHandler) -> Bool { // T: wlock by ctx
    #if swift(>=5)
      guard subscribers.firstIndex(where: {$0 === session}) == nil else {
        return false // already subscribed
      }
    #else
      guard subscribers.index(where: {$0 === session}) == nil else {
        return false // already subscribed
      }
    #endif
    
    subscribers.append(session)
    return true
  }
  
    internal func part(_ session: SessionHandler) -> Bool { // T: wlock by ctx
    #if swift(>=5)
      guard let idx = subscribers.firstIndex(where: {$0 === session}) else {
        return false // not subscribed
      }
    #else
      guard let idx = subscribers.index(where: {$0 === session}) else {
        return false // not subscribed
      }
    #endif
    
    subscribers.remove(at: idx)
    return true
  }
}

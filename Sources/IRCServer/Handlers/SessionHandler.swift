//import Foundation
//import NIO
//import NIOSSL
//import AsyncHTTPClient
//import NIOHTTP1
//#if os(macOS)
//import CryptoKit
//#else
//import Crypto
//#endif
//import Logging
//import NIOIRC
//
//
//
///// This `ChannelInboundHandler` demonstrates a few things:
/////   * Synchronisation between `EventLoop`s.
/////   * Mixing `Dispatch` and SwiftNIO.
/////   * `Channel`s are thread-safe, `ChannelHandlerContext`s are not.
/////
///// As we are using an `MultiThreadedEventLoopGroup` that uses more then 1 thread we need to ensure proper
///// synchronization on the shared state in the `SessionHandler` (as the same instance is shared across
///// child `Channel`s). For this a serial `DispatchQueue` is used when we modify the shared state (the `Dictionary`).
///// As `ChannelHandlerContext` is not thread-safe we need to ensure we only operate on the `Channel` itself while
///// `Dispatch` executed the submitted block.
//struct OurDate: Decodable {
//    let ourString: String
//}
//
//final class SessionHandler: ChannelInboundHandler, ServerMessageTarget {
//    
//    
//    typealias InboundIn = IRCMessage
//    typealias InboundOut = IRCMessage
//    
//    private let jsonDecoder: JSONDecoder
//    internal let serverContext: ServerContext
//    private let channelsSyncQueue = DispatchQueue(label: "channelsQueue")
//    private var channels: [ObjectIdentifier: Channel] = [:]
//    var channel   : NIO.Channel?
//    var eventLoop : NIO.EventLoop?
//    let logger    : Logger
//    
//    var mode = IRCUserMode()
//    
//    static let serverCapabilities : Set<String> = [ "multi-prefix" ]
//    var activeCapabilities = SessionHandler.serverCapabilities
//    
//    var joinedChannels = Set<IRCChannelName>()
//    
//    
//    var nick      : IRCNickName? { return state.nick }
//    var userID    : IRCUserID? {
//        guard case .registered(let nick, let info) = state else { return nil }
//        return IRCUserID(nick: nick, user: info.username,
//                         host: info.servername ?? origin)
//    }
//    
//    init(jsonDecoder: JSONDecoder = JSONDecoder(), logger: Logger, serverContext: ServerContext) {
//        self.jsonDecoder = jsonDecoder
//        self.logger = logger
//        self.serverContext = serverContext
//    }
//    
//    
//    public enum Error: Swift.Error {
//        case disconnected
//        case internalInconsistency
//    }
//    
//    public enum State: Equatable {
//        case initial
//        case nickAssigned(IRCNickName)
//        case userSet   (IRCUserInfo)
//        case registered(IRCNickName, IRCUserInfo)
//        
//        var nick: IRCNickName? {
//            switch self {
//            case .initial, .userSet: return nil
//            case .nickAssigned(let id): return id
//            case .registered(let id, _): return id
//            }
//        }
//        
//        var userInfo: IRCUserInfo? {
//            switch self {
//            case .initial, .nickAssigned: return nil
//            case .userSet(let info): return info
//            case .registered(_, let info): return info
//            }
//        }
//        
//        var isRegistered: Bool {
//            guard case .registered = self else { return false }
//            return true
//        }
//        
//        mutating func changeNick(to nick: IRCNickName) {
//            switch self {
//            case .initial:                 self = .nickAssigned(nick)
//            case .nickAssigned:              self = .nickAssigned(nick)
//            case .userSet      (let info): self = .registered(nick, info)
//            case .registered(_, let info): self = .registered(nick, info)
//            }
//        }
//        
//        public static func ==(lhs: State, rhs: State) -> Bool {
//            switch (lhs, rhs) {
//            case (.initial, .initial):
//                return true
//            case (.nickAssigned(let lhs), .nickAssigned(let rhs)):
//                return lhs == rhs
//            case (.userSet(let lhs), .userSet(let rhs)):
//                return lhs == rhs
//            case (.registered(let lu, let lui), .registered(let ru, let rui)):
//                return lu == ru && lui == rui
//            default: return false
//            }
//        }
//    }
//    
//    var state = State.initial {
//        didSet {
//            if oldValue.isRegistered != state.isRegistered && state.isRegistered {
//                //                                                sendWelecome()
//                sendCurrentMode()
//            }
//        }
//    }
//    
//    
//    public var origin : String? { return serverContext.origin }
//    public var target : String  { return nick?.stringValue ?? "*" }
//    
//    func sendMessages<T>(_ messages: T, promise: EventLoopPromise<Void>?) where T : Collection, T.Element == IRCMessage {
//        // TBD: this looks a little more difficult than necessary.
//        guard let channel = channel else {
//            promise?.fail(Error.disconnected)
//            return
//        }
//        
//        guard channel.eventLoop.inEventLoop else {
//            return channel.eventLoop.execute {
//                self.sendMessages(messages, promise: promise)
//            }
//        }
//        
//        let count = messages.count
//        if count == 0 {
//            promise?.succeed(())
//            return
//        }
//        if count == 1 {
//            return channel.writeAndFlush(messages.first!, promise: promise)
//        }
//        
//        guard let promise = promise else {
//            for message in messages {
//                channel.write(message, promise: nil)
//            }
//            return channel.flush()
//        }
//        
//        EventLoopFuture<Void>
//            .andAllSucceed(messages.map { channel.write($0) },
//                           on: promise.futureResult.eventLoop)
//            .cascade(to: promise)
//        
//        channel.flush()
//    }
//    
//    
//    //when we connect from the client we get shut dooen right away in the client
//    func channelActive(context: ChannelHandlerContext) {
//        assert(channel == nil, "channel is already set?!")
//        self.channel   = context.channel
//        self.eventLoop = context.channel.eventLoop
//
//        assert(state == .initial)
//
//        // TODO:
//        // - ident lookup
//        // - timeout until nick assignment!
//        print("CHANNEL ACTIVE \(context.channel)")
//        context.fireChannelActive()
//    }
//    
//    
//    
//    func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
//        print("CLOSE", context.channel, mode)
//        context.close(mode: mode, promise: promise)
//    }
//    
//    func channelInactive(context: ChannelHandlerContext) {
//        for channel in joinedChannels {
//            serverContext.partChannel(channel, session: self)
//        }
//        
//        if let nick = nick {
//            do {
//                try serverContext.unregisterSession(self, nick: nick)
//            }
//            catch {
//                logger.error("could not unregister session: \(nick)")
//            }
//        }
//        
//        context.fireChannelInactive()
//        
//        assert(channel === context.channel,
//               "different channel \(context) \(channel as Optional)")
//        channel = nil // release cycle
//        
//        // Note: we do NOT release the loop to avoid races!
//    }
//    
//    func errorCaught(context: ChannelHandlerContext, error: Error) {
//        print("ERROR", context.channel, error)
//        context.fireErrorCaught(error)
//    }
//
//    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
//        let message = self.unwrapInboundIn(data)
//        do {
//            try irc_msgSend(message)
//        }
//        catch let error as ServerError {
//            handleError(error, in: context)
//        }
//        catch {
//            errorCaught(context: context, error: error)
//        }
//    }
//    
//    func channelReadComplete(context: ChannelHandlerContext) {
//        context.flush()
//    }
//    
//    func handleError(_ error: ServerError, in context: ChannelHandlerContext) {
//        switch error {
//        case .nicknameInUse(let id):
//            sendError(.errorNicknameInUse, id.stringValue)
//            
//        case .noSuchNick(let id):
//            sendError(.errorNoSuchNick, id.stringValue)
//            
//        case .noSuchChannel(let channel):
//            sendError(.errorNoSuchChannel, channel.stringValue)
//            
//        case .alreadyRegistered:
//            assert(nick != nil, "ID not set, but 'already registered'?")
//            sendError(.errorAlreadyRegistered, nick?.stringValue ?? "?")
//            
//        case .notRegistered:
//            sendError(.errorNotRegistered)
//            
//        case .cantChangeModeForOtherUsers:
//            sendError(.errorUsersDontMatch,
//                      message: "Can't change mode for other users")
//            
//        case .doesNotRespondTo(let message):
//            sendError(.errorUnknownCommand, message.command.commandAsString)
//        }
//    }
//    
//    func handleError(_ error: IRCParserError, in context: ChannelHandlerContext) {
//        switch error {
//        case .invalidNickName(let id):
//            sendError(.errorErrorneusNickname, id,
//                      "Invalid Identity")
//            
//        case .invalidArgumentCount(let command, _, _):
//            sendError(.errorNeedMoreParams, command,
//                      "Not enough parameters")
//            
//        case .invalidChannelName(let name):
//            sendError(.errorIllegalChannelName, name,
//                      "Illegal channel name")
//            
//        default:
//            logger.error("Protocol error, sending unknown cmd \(error)")
//            sendError(.errorUnknownCommand, // TODO
//                      "?",
//                      "Protocol error")
//        }
//    }
//    
//    internal func errorCaught(context: ChannelHandlerContext, error: Swift.Error) {
//        if let ircError = error as? IRCParserError {
//            switch ircError {
//            case .transportError, .notImplemented:
//                context.fireErrorCaught(error)
//            default:
//                return handleError(ircError, in: context)
//            }
//        }
//        
//        context.fireErrorCaught(error)
//    }
//    
//    func sendCurrentMode() {
//        guard let nick = nick else { return }
//        let command = IRCCommand.MODE(nick, add: mode, remove: IRCUserMode())
//        sendMessage(IRCMessage(origin: origin, command: command))
//    }
//    
//    func sendWelcome() {
//        let nick   = state.nick?.stringValue ?? ""
//        let origin = self.origin ?? "??"
//        let info   = serverContext.getServerInfo()
//        
//        sendReply(.replyWelcome,
//                  "Welcome to the NIO Internet Relay Chat Network \(nick)")
//        sendReply(.replyYourHost, "Your host is \(origin), running miniircd")
//        sendReply(.replyCreated, "This server was created \(serverContext.created)")
//        
//        sendReply(.replyMyInfo, "\(origin) miniircd")
//        sendReply(.replyBounce, "CHANTYPES=#", "CHANLIMIT=#:120", "NETWORK=NIO",
//                  "are supported by this server")
//        
//        sendReply(.replyLUserClient,
//                  "There are \(info.userCount) users and " +
//                    "\(info.invisibleCount) invisible on \(info.serverCount) servers")
//        sendReply(.replyLUserOp, "\(info.operatorCount)", "IRC Operators online")
//        sendReply(.replyLUserChannels, "\(info.channelCount)", "channels formed")
//        
//        sendMotD("""
//               Welcome to \(origin) at Cartisim.
//               """)
//    }
//}
//
//extension SessionHandler : EventLoopObject {}
//
//extension SessionHandler {
//    
//    /// Grab values from a collection of `IRCSessionHandler` objects. Since those
//    /// can run in different threads, this thing gets a little more difficult
//    /// than what you may think ;-)
//    func getValues<C: Collection, T>(from sessions: C,
//                                     map   : @escaping ( SessionHandler ) -> T,
//                                     yield : @escaping ( [ T ] ) -> Void)
//    where C.Element == SessionHandler
//    {
//        // Careful: This only works on sessions which have been activated,
//        //          which in turn guarantees, that they have a loop!
//        guard let yieldLoop = self.eventLoop else {
//            assert(eventLoop != nil, "called getValues on handler w/o loop?! \(self)")
//            return yield([])
//        }
//        
//        let promise = yieldLoop.makePromise(of: [ T ].self)
//        SessionHandler.getValues(from: sessions, map: map, promise: promise)
//        _ = promise.futureResult.map(yield)
//    }
//}
//
//protocol EventLoopObject {
//    
//    var eventLoop : EventLoop? { get }
//    
//}
//
//import class Dispatch.DispatchQueue
//
//extension EventLoopObject {
//    
//    static func getValues<C: Collection, T>(from objects: C,
//                                            map : @escaping ( C.Element ) -> T,
//                                            promise : EventLoopPromise<[ T ]>)
//    where C.Element : EventLoopObject
//    {
//        guard !objects.isEmpty else { return promise.succeed([]) }
//        
//        var expectedCount = 0
//        var loopToObjects = [ ObjectIdentifier : [ C.Element ] ]()
//        for object in objects {
//            guard let hLoop = object.eventLoop else {
//                // TBD: we could fail the promise, but here we just skip
//                assert(object.eventLoop != nil,
//                       "called \(#function) on object w/o loop!")
//                continue
//            }
//            
//            let oid = ObjectIdentifier(hLoop)
//            if nil == loopToObjects[oid]?.append(object) {
//                loopToObjects[oid] = [ object ]
//            }
//            expectedCount += 1
//        }
//        
//        let syncQueue = DispatchQueue(label: "io.cartisim.nio.util.collector")
//        var values = [ T ]()
//        values.reserveCapacity(objects.count)
//        
//        for ( _, handlerGroup ) in loopToObjects {
//            let loop = handlerGroup[0].eventLoop!
//            loop.execute {
//                let elValues = Array(handlerGroup.map(map))
//                syncQueue.async {
//                    values.append(contentsOf: elValues)
//                    expectedCount -= elValues.count
//                    if expectedCount < 1 {
//                        promise.succeed(values)
//                    }
//                }
//            }
//        }
//    }
//}

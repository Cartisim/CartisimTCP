import Foundation
import NIO
import NIOSSL
import AsyncHTTPClient
import NIOHTTP1
#if os(macOS)
import CryptoKit
#else
import Crypto
#endif
import Logging



/// This `ChannelInboundHandler` demonstrates a few things:
///   * Synchronisation between `EventLoop`s.
///   * Mixing `Dispatch` and SwiftNIO.
///   * `Channel`s are thread-safe, `ChannelHandlerContext`s are not.
///
/// As we are using an `MultiThreadedEventLoopGroup` that uses more then 1 thread we need to ensure proper
/// synchronization on the shared state in the `SessionHandler` (as the same instance is shared across
/// child `Channel`s). For this a serial `DispatchQueue` is used when we modify the shared state (the `Dictionary`).
/// As `ChannelHandlerContext` is not thread-safe we need to ensure we only operate on the `Channel` itself while
/// `Dispatch` executed the submitted block.
struct OurDate: Decodable {
    let ourString: String
}

final class SessionHandler: ChannelInboundHandler, ServerMessageTarget {

    
    typealias InboundIn = Message
    typealias InboundOut = Message
    
    private let jsonDecoder: JSONDecoder
    internal let serverContext: ServerContext
    private let channelsSyncQueue = DispatchQueue(label: "channelsQueue")
    private var channels: [ObjectIdentifier: Channel] = [:]
    var channel   : NIO.Channel?
    var eventLoop : NIO.EventLoop?
    let logger    : Logger
    
    var mode = UserMode()

    static let serverCapabilities : Set<String> = [ "multi-prefix" ]
    var activeCapabilities = SessionHandler.serverCapabilities

    var joinedChannels = Set<ChannelName>()
    

    var id      : DMIdentifier? { return state.id }
    var userID    : UserID? {
        guard case .registered(let id, let info) = state else { return nil }
        return UserID(id: id, user: info.username,
                      host: info.servername ?? origin)
    }
    
    init(jsonDecoder: JSONDecoder = JSONDecoder(), logger: Logger, serverContext: ServerContext) {
        self.jsonDecoder = jsonDecoder
        self.logger = logger
        self.serverContext = serverContext
    }
    
    
    public enum Error: Swift.Error {
        case disconnected
        case internalInconsistency
    }
    
    public enum State: Equatable {
        case initial
        case idAssigned(DMIdentifier)
        case userSet   (UserInfo)
        case registered(DMIdentifier, UserInfo)
        
        var id: DMIdentifier? {
            switch self {
            case .initial, .userSet: return nil
            case .idAssigned(let id): return id
            case .registered(let id, _): return id
            }
        }
        
        var userInfo: UserInfo? {
            switch self {
            case .initial, .idAssigned: return nil
            case .userSet(let info): return info
            case .registered(_, let info): return info
            }
        }
        
        var isRegistered: Bool {
            guard case .registered = self else { return false }
            return true
        }
        
        mutating func changeID(to id: DMIdentifier) {
            switch self {
            case .initial:                 self = .idAssigned(id)
            case .idAssigned:              self = .idAssigned(id)
            case .userSet      (let info): self = .registered(id, info)
            case .registered(_, let info): self = .registered(id, info)
            }
        }
        
        public static func ==(lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.initial, .initial):
                return true
            case (.idAssigned(let lhs), .idAssigned(let rhs)):
                return lhs == rhs
            case (.userSet(let lhs), .userSet(let rhs)):
                return lhs == rhs
            case (.registered(let lu, let lui), .registered(let ru, let rui)):
                return lu == ru && lui == rui
            default: return false
            }
        }
    }
    
    var state = State.initial {
        didSet {
            if oldValue.isRegistered != state.isRegistered && state.isRegistered {
                //                sendWelecome()
                //                sendCurrentMode()
            }
        }
    }
    
    
    public var origin : String? { return serverContext.origin }
    public var target : String  { return id?.stringValue ?? "*" }
    
    func sendMessages<T>(_ messages: T, promise: EventLoopPromise<Void>?) where T : Collection, T.Element == Message {
          // TBD: this looks a little more difficult than necessary.
          guard let channel = channel else {
            #if swift(>=5) // NIO 2 API
              promise?.fail(Error.disconnected)
            #else // NIO 1 API
              promise?.fail(error: Error.disconnected)
            #endif
            return
          }
          
          guard channel.eventLoop.inEventLoop else {
            return channel.eventLoop.execute {
              self.sendMessages(messages, promise: promise)
            }
          }
          
          let count = messages.count
          if count == 0 {
            #if swift(>=5) // NIO 2 API
              promise?.succeed(())
            #else
              promise?.succeed(result: ())
            #endif
            return
          }
          if count == 1 {
            return channel.writeAndFlush(messages.first!, promise: promise)
          }
          
          guard let promise = promise else {
            for message in messages {
              channel.write(message, promise: nil)
            }
            return channel.flush()
          }
          
          #if swift(>=5) // NIO 2 API
            EventLoopFuture<Void>
              .andAllSucceed(messages.map { channel.write($0) },
                             on: promise.futureResult.eventLoop)
              .cascade(to: promise)
          #else
            EventLoopFuture<Void>
              .andAll(messages.map { channel.write($0) },
                      eventLoop: promise.futureResult.eventLoop)
              .cascade(promise: promise)
          #endif
          
          channel.flush()
        }
    
    
    func channelActive(context: ChannelHandlerContext) {
        let channel = context.channel
        self.channelsSyncQueue.async { [self] in
            self.channels[ObjectIdentifier(channel)] = channel
        }
        
        print("(ChatServer) - Welcome to: \(context.localAddress!)\n")
        context.fireChannelActive()
    }
    
    
    func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        print("CLOSE", context.channel, mode)
        context.close(mode: mode, promise: promise)
    }
    
    func channelInactive(context: ChannelHandlerContext) {
        let channel = context.channel
        print(channel, "INACTIVE")
        self.channelsSyncQueue.async {
            if self.channels.removeValue(forKey: ObjectIdentifier(channel)) != nil {
                self.writeToAllInactive(channels: self.channels, allocator: channel.allocator, message: "(ChatServer) - Client disconnected\n")
            }
        }
        context.fireChannelInactive()
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("ERROR", context.channel, error)
        context.fireErrorCaught(error)
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let message = self.unwrapInboundIn(data)
        do {
          try irc_msgSend(message)
        }
        catch let error as ServerError {
          handleError(error, in: context)
        }
        catch {
          errorCaught(context: context, error: error)
        }
    }
    
    func handleError(_ error: ServerError, in context: ChannelHandlerContext) {
      switch error {
        case .identifierInUse(let id):
          sendError(.errorIdentityInUse, id.stringValue)
        
        case .noSuchIdentifier(let id):
          sendError(.errorNoSuchDMID, id.stringValue)
        
        case .noSuchChannel(let channel):
          sendError(.errorNoSuchChannel, channel.stringValue)

        case .alreadyRegistered:
          assert(id != nil, "ID not set, but 'already registered'?")
          sendError(.errorAlreadyRegistered, id?.stringValue ?? "?")
        
        case .notRegistered:
          sendError(.errorNotRegistered)
        
        case .cantChangeModeForOtherUsers:
          sendError(.errorUsersDontMatch,
                    message: "Can't change mode for other users")
        
        case .doesNotRespondTo(let message):
          sendError(.errorUnknownCommand, message.command.commandAsString)
      }
    }

    func handleError(_ error: ParserError, in context: ChannelHandlerContext) {
      switch error {
      case .invalidDMID(let id):
          sendError(.errorErrorneusIdentity, id,
                    "Invalid Identity")
        
        case .invalidArgumentCount(let command, _, _):
          sendError(.errorNeedMoreParams, command,
                    "Not enough parameters")
        
        case .invalidChannelName(let name):
          sendError(.errorIllegalChannelName, name,
                    "Illegal channel name")
        
        default:
          logger.error("Protocol error, sending unknown cmd \(error)")
          sendError(.errorUnknownCommand, // TODO
                    "?",
                    "Protocol error")
      }
    }
    
    internal func errorCaught(context: ChannelHandlerContext, error: Swift.Error) {
      if let ircError = error as? ParserError {
        switch ircError {
          case .transportError, .notImplemented:
            context.fireErrorCaught(error)
          default:
            return handleError(ircError, in: context)
        }
      }
      
      context.fireErrorCaught(error)
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
    
    private func writeToAllInactive(channels: [ObjectIdentifier: Channel], allocator: ByteBufferAllocator, message: String) {
        let buffer =  allocator.buffer(string: message)
        self.writeMessageToAll(channels: channels, buffer: buffer)
    }
    
    private func writeMessageToAll(channels: [ObjectIdentifier: Channel], buffer: ByteBuffer) {
        channels.forEach { $0.value.writeAndFlush(buffer, promise: nil) }
    }
    
    private func writeToAll(channels: [ObjectIdentifier: Channel], object: Message) {
        channels.forEach { $0.value.writeAndFlush(object, promise: nil) }
    }
    
}

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

final class SessionHandler<Message: Decodable>: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = Message
    
    private let jsonDecoder: JSONDecoder
    //    static let serverCapabilities: Set<String> = ["multi-prefix"]
    //    var activeCapabilities = SessionHandler.serverCapabilities
        private let serverContext: ServerContext
        private let channelsSyncQueue = DispatchQueue(label: "channelsQueue")
        private var channels: [ObjectIdentifier: Channel] = [:]
    
    init(jsonDecoder: JSONDecoder = JSONDecoder(), serverContext: ServerContext) {
        self.jsonDecoder = jsonDecoder
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

    var userID: UserID? {
        guard case .registered(let id, let info) = state else { return nil }
        return UserID(id: id, user: info.username, host: info.servername ?? origin)
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
        let bytes = self.unwrapInboundIn(data)
//                var buffer = context.channel.allocator.buffer(capacity: bytes.readableBytes + 64)
//                guard let received = buffer.readString(length: bytes.readableBytes) else {return}
//                buffer.writeString("\(bytes)")
//                print(received, "Received On Post Message")
        do {
            try postMessage(context: context, bytes: bytes)
        } catch {
            context.fireErrorCaught(error)
        }
    }
    
    fileprivate func postMessage(context: ChannelHandlerContext, bytes: ByteBuffer) throws {
        do {
            guard let object = try? self.jsonDecoder.decode(Message.self, from: bytes) as? EncryptedObject else {return}
            guard let decryptedObject = CartisimCrypto.decryptableResponse(MessageData.self, string: object.encryptedObjectString) else {return}
            var request = try HTTPClient.Request(url: "\(Constants.BASE_URL)post-message/\(decryptedObject.sessionID)", method: .POST)
            guard let access = decryptedObject.accessToken else { throw AuthenticationError.refreshTokenOrUserNotFound("Refresh Token Not Found") }
            request.headers.add(contentsOf: Headers.headers(token: access))
            guard let body = try? JSONEncoder().encode(object) else {return}
            request.body = .data(body)
            TCPServer.httpClient?.execute(request: request).flatMapThrowing { result in
                if result.status == .ok {
                    print(result.status, "Response")
                    self.channelsSyncQueue.async {
                        do {
                            guard let data = result.body else {return}
                            let object = try self.jsonDecoder.decode(Message.self, from: data) as? EncryptedObject
                            self.writeToAll(channels: self.channels, object: object as! Message)
                        } catch {
                            context.fireErrorCaught(error)
                        }
                    }
                } else {
                    print(result, "Remote Error")
                    if result.status == .unauthorized {
                        guard let refresh = decryptedObject.refreshToken else { throw AuthenticationError.refreshTokenOrUserNotFound("Refresh Token Not Found") }
                        self.refreshToken(context: context, token: refresh, object: object)
                    }
                }
            }.whenFailure { (error) in
                print(error, "Error in Chat handler")
            }
        } catch {
            print(error, "Error In HTTP Request")
        }
    }
    
    fileprivate func refreshToken(context: ChannelHandlerContext, token: String, object: EncryptedObject) {
        let id = ObjectIdentifier(context.channel)
        var request = try! HTTPClient.Request(url: "\(Constants.BASE_URL)auth/access-token", method: .POST)
        request.headers.add(contentsOf: Headers.headers(token: token))
        guard let body = try? JSONEncoder().encode(object) else {return}
        request.body = .data(body)
        TCPServer.httpClient?.execute(request: request).map { result in
            if result.status == .ok {
                print(result, "Response")
                self.channelsSyncQueue.async {
                    do {
                        guard let data = result.body else {return}
                        guard let object = try self.jsonDecoder.decode(Message.self, from: data) as? EncryptedObject else {return}
                        self.writeToAll(channels: self.channels.filter { id == $0.key }, object: object as! Message)
                        
                        guard let decryptedObject = CartisimCrypto.decryptableResponse(MessageData.self, string: object.encryptedObjectString) else {return}
                        guard let decryptedRefreshObject = CartisimCrypto.decryptableResponse(RefreshRequest.self, string: object.encryptedObjectString) else {return}
                        
                        var request = try HTTPClient.Request(url: "\(Constants.BASE_URL)post-message/\(decryptedObject.sessionID)", method: .POST)
                        request.headers.add(contentsOf: Headers.headers(token:decryptedRefreshObject.accessToken))
                        guard let refresh = decryptedObject.refreshToken else { throw AuthenticationError.refreshTokenOrUserNotFound("Refresh Token Not Found") }
                        let token = RefreshToken(refreshToken: refresh)
                        guard let refreshBody = try? JSONEncoder().encode(CartisimCrypto.encryptableBody(body: token.requestRefreshTokenObject())) else {return}
                        
                        request.body = .data(refreshBody)
                        TCPServer.httpClient?.execute(request: request).map { result in
                            print(result.status, "Post Message Status In Refresh Handler")
                            if result.status == .ok {
                                self.channelsSyncQueue.async {
                                    do {
                                        guard let data = result.body else {return}
                                        let object = try self.jsonDecoder.decode(Message.self, from: data) as? EncryptedObject
                                        self.writeToAll(channels: self.channels, object: object as! Message)
                                    } catch {
                                        context.fireErrorCaught(error)
                                    }
                                }
                            } else {
                                print(result, "Remote Error")
                            }
                        }.whenFailure { (error) in
                            print(error, "Error in Chat handler")
                        }
                    } catch {
                        context.fireErrorCaught(error)
                    }
                }
            } else {
                print(result.status, "Refresh Error")
            }
        }.whenFailure { (error) in
            print(error, "Error in Chat handler")
        }
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
    
    
    public var origin: String? { return serverContext.origin }
}

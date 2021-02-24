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
/// synchronization on the shared state in the `ChatHandler` (as the same instance is shared across
/// child `Channel`s). For this a serial `DispatchQueue` is used when we modify the shared state (the `Dictionary`).
/// As `ChannelHandlerContext` is not thread-safe we need to ensure we only operate on the `Channel` itself while
/// `Dispatch` executed the submitted block.
struct OurDate: Decodable {
    let ourString: String
}

final class ChatHandler: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer
    
    private let channelsSyncQueue = DispatchQueue(label: "channelsQueue")
    private var channels: [ObjectIdentifier: Channel] = [:]
    
    
    public func channelActive(context: ChannelHandlerContext) {
        print("ACTIVE")
        //        let remoteAddress = context.remoteAddress!
        let channel = context.channel
        self.channelsSyncQueue.async { [self] in
            //            self.writeToAll(channels: self.channels, allocator: channel.allocator, message: "(ChatServer) - New client connected with address: \(remoteAddress)\n")
            self.channels[ObjectIdentifier(channel)] = channel
        }
        
        print("(ChatServer) - Welcome to: \(context.localAddress!)\n")
        
        context.fireChannelActive()
    }
    
    
    public func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        print("CLOSE", context.channel, mode)
        context.close(mode: mode, promise: promise)
    }
    
    public func channelInactive(context: ChannelHandlerContext) {
        let channel = context.channel
        print(channel, "INACTIVE")
        self.channelsSyncQueue.async {
            if self.channels.removeValue(forKey: ObjectIdentifier(channel)) != nil {
                self.writeToAllInactive(channels: self.channels, allocator: channel.allocator, message: "(ChatServer) - Client disconnected\n")
            }
        }
        context.fireChannelInactive()
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("ERROR", context.channel, error)
        context.fireErrorCaught(error)
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var read = self.unwrapInboundIn(data)
        var buffer = context.channel.allocator.buffer(capacity: read.readableBytes + 64)
        guard let received = read.readString(length: read.readableBytes) else {return}
        buffer.writeString("\(received)")
        print(received, "Received On Post Message")
        postMessage(context: context, buffer: buffer)
    }
    
    fileprivate func postMessage(context: ChannelHandlerContext, buffer: ByteBuffer) {
        let object = try? JSONDecoder().decode(EncryptedAuthRequest.self, from: buffer)
        guard let decryptedObject = CartisimCrypto.decryptableResponse(ChatroomRequest.self, string: object!.encryptedObject) else {return}
        var request = try! HTTPClient.Request(url: "\(Constants.BASE_URL)postMessage/\(decryptedObject.sessionID)", method: .POST)

        request.headers.add(contentsOf: Headers.headers(token: decryptedObject.accessToken))
        print(decryptedObject.accessToken, "ACCESS_TOKEN_____________")
        guard let body = try? JSONEncoder().encode(object) else {return}
        request.body = .data(body)
        TCPServer.httpClient?.execute(request: request).map { result in
            if result.status == .ok {
                print(result, "Response")
                self.channelsSyncQueue.async {
                    guard let data = result.body else {return}
                    print(self.channels, "Channels")
                    self.writeToAll(channels: self.channels, buffer: data)
                }
            } else {
                print(result, "Remote Error")
                if result.status == .unauthorized {
                    guard let o = object else {return}
                    self.refreshToken(context: context, token: decryptedObject.refreshToken, object: o)
                }
            }
        }.whenFailure { (error) in
            print(error, "Error in Chat handler")
        }
    }
    
    fileprivate func refreshToken(context: ChannelHandlerContext, token: String, object: EncryptedAuthRequest) {
        let id = ObjectIdentifier(context.channel)
        var request = try! HTTPClient.Request(url: "\(Constants.BASE_URL)auth/accessToken", method: .POST)
        request.headers.add(contentsOf: Headers.headers(token: token))
        guard let body = try? JSONEncoder().encode(object) else {return}
        request.body = .data(body)
        TCPServer.httpClient?.execute(request: request).map { result in
            if result.status == .ok {
                print(result, "Response")
                self.channelsSyncQueue.async {
                    guard let data = result.body else {return}
                    
                    self.writeToAll(channels: self.channels.filter { id == $0.key }, buffer: data)
                    
                    guard let decryptedObject = CartisimCrypto.decryptableResponse(ChatroomRequest.self, string: object.encryptedObject) else {return}
                    var request = try! HTTPClient.Request(url: "\(Constants.BASE_URL)postMessage/\(decryptedObject.sessionID)", method: .POST)
                    guard let body = try? JSONEncoder().encode(object) else {return}
                    request.body = .data(body)
                    TCPServer.httpClient?.execute(request: request).map { result in
                        if result.status == .ok {
                            print(result, "Response")
                            self.channelsSyncQueue.async {
                                guard let data = result.body else {return}
                                print(self.channels, "Channels")
                                self.writeToAll(channels: self.channels, buffer: data)
                                
                            }
                        } else {
                            print(result, "Remote Error")
                        }
                    }.whenFailure { (error) in
                        print(error, "Error in Chat handler")
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
        self.writeToAll(channels: channels, buffer: buffer)
    }
    
    private func writeToAll(channels: [ObjectIdentifier: Channel], buffer: ByteBuffer) {
        channels.forEach { $0.value.writeAndFlush(buffer, promise: nil) }
    }
}


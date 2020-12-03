import Foundation
import NIO
import Fluent
import Vapor

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
    
    // All access to channels is guarded by channelsSyncQueue.
    private let channelsSyncQueue = DispatchQueue(label: "channelsQueue")
    private var channels: [ObjectIdentifier: Channel] = [:]
    
    public func channelActive(context: ChannelHandlerContext) {
        let remoteAddress = context.remoteAddress!
        let channel = context.channel
        print(channel,remoteAddress, "ACTIVE")
        self.channelsSyncQueue.async {
            // broadcast the message to all the connected clients except the one that just became active.
            self.writeToAll(channels: self.channels, allocator: channel.allocator, message: "(ChatServer) - New client connected with address: \(remoteAddress)\n")
            
            self.channels[ObjectIdentifier(channel)] = channel
        }
        
        var buffer = channel.allocator.buffer(capacity: 64)
        buffer.writeString("(ChatServer) - Welcome to: \(context.localAddress!)\n")
        context.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
    }
    
    public func channelInactive(context: ChannelHandlerContext) {
        let channel = context.channel
        print(channel, "INACTIVE")
        self.channelsSyncQueue.async {
            if self.channels.removeValue(forKey: ObjectIdentifier(channel)) != nil {
                // Broadcast the message to all the connected clients except the one that just was disconnected.
                self.writeToAll(channels: self.channels, allocator: channel.allocator, message: "(ChatServer) - Client disconnected\n")
            }
        }
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let id = ObjectIdentifier(context.channel)
        var read = self.unwrapInboundIn(data)
        print(id, "ID")
        // 64 should be good enough for the ipaddress
        var buffer = context.channel.allocator.buffer(capacity: read.readableBytes + 64)
        guard let received = read.readString(length: read.readableBytes) else {return}
        buffer.writeString("\(received)")
//        buffer.writeString("(\(context.remoteAddress!)) - ")
//        buffer.writeBuffer(&read)
        self.channelsSyncQueue.async {
            // broadcast the message to all the connected clients except the one that wrote it.
//            self.writeToAll(channels: self.channels.filter { id != $0.key }, buffer: buffer)
            self.writeToAll(channels: self.channels, buffer: buffer)
            
        }
        
        
//        let app = Application()
//        let req = Request(application: app, on: app.client.eventLoop)
//        return req.client.post("", headers: ["":""]) { (res) in
//            try req.content.encode(["data":"\(data)"], as: .json)
//        }.transform(to: HTTPStatus.ok)
    }
    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)
        
        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }
    
    private func writeToAll(channels: [ObjectIdentifier: Channel], allocator: ByteBufferAllocator, message: String) {
        let buffer =  allocator.buffer(string: message)
        self.writeToAll(channels: channels, buffer: buffer)
    }
    
    private func writeToAll(channels: [ObjectIdentifier: Channel], buffer: ByteBuffer) {
        channels.forEach { $0.value.writeAndFlush(buffer, promise: nil) }
    }
}



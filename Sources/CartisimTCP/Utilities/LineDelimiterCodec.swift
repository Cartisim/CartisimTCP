//import NIO
//
//private let newLine = "\n".utf8.first!
//
///// Very simple example codec which will buffer inbound data until a `\n` was found.
//final class LineDelimiterCodec: ByteToMessageDecoder {
//    public typealias InboundIn = ByteBuffer
//    public typealias InboundOut = ByteBuffer
//
//    public var cumulationBuffer: ByteBuffer?
//
//    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
//        let readable = buffer.withUnsafeReadableBytes { $0.firstIndex(of: newLine) }
//        if let r = readable {
//            context.fireChannelRead(self.wrapInboundOut(buffer.readSlice(length: r + 1)!))
//            return .continue
//        }
//        return .needMoreData
//    }
//}
//
//

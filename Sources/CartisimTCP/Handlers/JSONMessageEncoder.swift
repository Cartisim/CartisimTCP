import Foundation
import NIO


final class JSONMessageEncoder<Message: Encodable>: MessageToByteEncoder {
    typealias OutboundIn = Message
    let jsonEncoder: JSONEncoder
    
    init(jsonEncoder: JSONEncoder = JSONEncoder()) {
        self.jsonEncoder = jsonEncoder
    }
    
    func encode(data: Message, out: inout ByteBuffer) throws {
        try self.jsonEncoder.encode(data, into: &out)
        assert(!out.readableBytesView.contains(UInt8(ascii: "\n")),
               "Foundation.JSONEncoder encoded a newline into the output for \(data), this will fail decoding. Please configure JSONEncoder differently")
        out.writeStaticString("\n")
    }
}

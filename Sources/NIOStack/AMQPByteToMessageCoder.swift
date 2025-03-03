import Foundation
import NIOCore
import NIOFoundationCompat

struct AMQPByteToMessageCoder: ByteToMessageDecoder, MessageToByteEncoder {
    // MARK: - ByteToMessageDecoder
    typealias InboundOut = AMQPFrame

    mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws
        -> DecodingState
    {
        // TODO: this is a bit of duplicate code as the same happens within the AMQPFrame...
        // would be really nice to change how I parse things to "stream" later
        let type = buffer.getInteger(at: 0, endianness: .big, as: UInt8.self)
        let channelId = buffer.getInteger(at: 1, endianness: .big, as: UInt16.self)
        let expectedSize = buffer.getInteger(at: 3, endianness: .big, as: UInt32.self)
        guard type != nil, channelId != nil, let expectedSize else {
            return .needMoreData
        }
        // 8 is standard overhead for frame = size(type) + size(channelId) + size(expectedSize) + size(endFrame)
        let frameSizeOverhead: Int = 8
        let totalFrameSize = Int(expectedSize) + frameSizeOverhead
        if totalFrameSize != buffer.readableBytes {
            return .needMoreData
        }
        do {
            let data = buffer.readData(length: totalFrameSize) ?? Data()
            let frame = try FrameDecoder().decode(AMQPFrame.self, from: data)
            context.fireChannelRead(self.wrapInboundOut(frame))
        } catch {
            context.fireErrorCaught(error)
        }
        return .continue
    }

    mutating func decodeLast(
        context: ChannelHandlerContext,
        buffer: inout ByteBuffer,
        seenEOF: Bool
    ) throws -> DecodingState {
        .needMoreData
    }

    // MARK: - MessageToByteEncoder
    typealias OutboundIn = AMQPFrame

    func encode(data: OutboundIn, out: inout NIOCore.ByteBuffer) throws {
        out = ByteBuffer(data: try data.asFrame())
    }

    // MARK: - init
    init() {}
}

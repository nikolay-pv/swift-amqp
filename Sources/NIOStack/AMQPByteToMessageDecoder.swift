import Foundation
import NIOCore
import NIOFoundationCompat

struct AMQPByteToMessageDecoder: ByteToMessageDecoder {
    // MARK: - ByteToMessageDecoder
    typealias InboundOut = AMQPFrame

    mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws
        -> DecodingState
    {
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

    // MARK: - init
    init() {}
}

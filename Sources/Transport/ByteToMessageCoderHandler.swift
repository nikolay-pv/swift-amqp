import Foundation
import NIOCore
import NIOFoundationCompat

struct ByteToMessageCoderHandler: ByteToMessageDecoder, MessageToByteEncoder {
    // MARK: - ByteToMessageDecoder
    typealias InboundOut = Frame

    mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws
        -> DecodingState
    {
        // peek inside the buffer to know how much data expected
        let type = buffer.getInteger(at: 0, endianness: .big, as: UInt8.self)
        let channelId = buffer.getInteger(at: 1, endianness: .big, as: UInt16.self)
        let expectedSize = buffer.getInteger(at: 3, endianness: .big, as: UInt32.self)
        guard let type, channelId != nil, let expectedSize else {
            return .needMoreData
        }
        // 8 is standard overhead for frame = size(type) + size(channelId) + size(expectedSize) + size(endFrame)
        let frameSizeOverhead: Int = 8
        let totalFrameSize = Int(expectedSize) + frameSizeOverhead
        if buffer.readableBytes < totalFrameSize {
            return .needMoreData
        }
        do {
            // force unwrapping is safe because of the previous check
            let data = buffer.readData(length: totalFrameSize)!
            let frame = try decodeFrame(type: type, from: data)
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
    typealias OutboundIn = Frame

    func encode(data: OutboundIn, out: inout NIOCore.ByteBuffer) throws {
        out = ByteBuffer(data: try data.asData())
    }

    // MARK: - init
    init() {}
}

import NIOCore

internal typealias ByteArray = ByteBuffer

extension ByteArray {
    func subdata(in range: Range<Int>) -> ByteBuffer {
        // the nil is returned when bytes are not readable, shouldn't happen so return empty range in case it happens
        return self.getSlice(at: range.startIndex, length: range.count) ?? .init()
    }

    var count: Int {
        return self.readableBytes
    }
}

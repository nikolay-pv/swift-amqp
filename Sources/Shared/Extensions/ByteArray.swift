internal typealias ByteArray = [UInt8]

extension ByteArray {
    func subdata(in range: Range<ByteArray.Index>) -> ArraySlice<UInt8> {
        return self[range]
    }
}

extension String {
    var isShort: Bool { self.utf8.count <= UInt8.max - 1 }

    /// Returns the number of bytes this object will need when serialized according to AMQP specification.
    /// Short string can't be longer than `UInt8.max - 1` elements (1 byte is required to store the length).
    /// see 4.9 Limitations
    var shortBytesCount: UInt8 {
        let size = UInt8(self.utf8.count)
        precondition(size <= UInt8.max - 1, "String is too long")
        return size + 1
    }

    /// Returns the number of bytes this object will need when serialized according to AMQP specification.
    /// Long string can't be longer than `UInt32.max - 4` elements (4 bytes are required to store the length).
    /// see 4.9 Limitations
    var longBytesCount: UInt32 {
        let size = UInt32(self.utf8.count)
        precondition(self.utf8.count <= UInt32.max - 4, "String is too long")
        return size + 4
    }
}

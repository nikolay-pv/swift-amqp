extension Spec.Table {
    /// Returns number of bytes this object will need when serializes according to AMQP specification.
    /// The number of bites needed is a sum of:
    ///  - the size of the table in bytes stored as UInt32 (4 bytes)
    ///  - key of the table stored as a short string (see `String.shortBytesCount`)
    ///  - value of the corresponding key which is represented with `FieldValue`
    var bytesCount: UInt32 {
        4
            + self.reduce(into: UInt32(0)) {
                $0 += UInt32($1.key.shortBytesCount) + $1.value.bytesCount
            }
    }
}

enum ConnectionError: Error {
    case connectionIsClosed
    case connectionFailed(reason: String)
}

enum NegotiationError: Error {
    case protocolVersionMismatch(server: String, client: String)
    case unsupportedAuthMechanism(String)
    /// throws when protocol negotiation is somehow waited on different method from the broker
    case unexpectedMethod
    case unknown
}

enum FramingError: Error {
    case fatal(String)
    case unknownClassAndMethod(class: UInt16, method: UInt16)
    case unknownFrameType(_ type: UInt8)
}

enum TransportError: Error {
}

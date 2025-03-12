enum ConnectionError: Error {
    case protocolVersionMismatch(server: String, client: String)
    case unsupportedAuthMechanism(String)
    case unknown
}

enum FramingError: Error {
    case fatal(String)
    case unknownClassAndMethod(class: UInt16, method: UInt16)
    case unknownFrameType(_ type: UInt8)
}

enum TransportError: Error {
}

enum ConnectionError: Error {
    case ProtocolVersionMismatch(server: String, client: String)
    case UnsupportedAuthMechanism(String)
    case Unknown
}

enum FramingError: Error {
    case Fatal(String)
    case UnknownClassAndMethod(class: UInt16, method: UInt16)
    case UnknownFrameType(_ type: UInt8)
}

enum TransportError: Error {
}

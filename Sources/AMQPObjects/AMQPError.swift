// TODO: improve this (& +messaging + internal / external split)
enum AMQPError {
    enum CodingError: Error {
        case unknownClassAndMethod(class: UInt16, method: UInt16)
        case unknownFrameType(_ type: UInt8)
    }

    enum ProtocolNegotiationError: Error {
        case versionMismatch(String)
        case authentication(String)
        case unknown
    }
}

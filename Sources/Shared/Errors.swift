enum ConnectionError: Error {
    // means that this connection can't be used anymore and should be recreated
    case connectionIsClosed(String)

    // this means that Channel has been closed and should be recreated
    case channelIsClosed
    // thrown when trying to create more channels than allowed in negotiation
    // (everything can be still used as normal, but new channel can be made only
    // if some are closed)
    case maxChannelsLimitReached

    static let connectionIsClosed = Self.connectionIsClosed("")

    static func wrap(hardError: HardError) -> ConnectionError {
        switch hardError {
        case .broker(let code, let replyText, classId: _, methodId: _):
            return Self.connectionIsClosed("by broker: \(code) \(replyText)")
        case .client(let code, let replyText, classId: _, methodId: _):
            return Self.connectionIsClosed("by client: \(code) \(replyText)")
        }
    }
}

extension ConnectionError: Equatable {}

// represents errors which shouldn't leave the client and be shown to users
protocol InternalError: Error {}

enum NegotiationError: InternalError {
    case protocolVersionMismatch(server: String, client: String)
    case unsupportedAuthMechanism(String)
    /// throws when protocol negotiation is somehow waited on different method from the broker
    case unexpectedMethod
    /// thrown if the frames are not arriving from Server in time of the fixed timeout
    case timedOut
    case unknown
}

enum FramingError: InternalError {
    case fatal(String)
    case unknownClassAndMethod(class: UInt16, method: UInt16)
    case unknownFrameType(_ type: UInt8)
}

// Soft and Hard errors defined by spec
protocol ProtocolError: InternalError {}

enum SoftError: ProtocolError {
    case broker(code: Spec.SoftError, replyText: String, classId: UInt16, methodId: UInt16)
    case client(code: Spec.SoftError, replyText: String, classId: UInt16, methodId: UInt16)
}

enum HardError: ProtocolError {
    case broker(code: Spec.HardError, replyText: String, classId: UInt16, methodId: UInt16)
    case client(code: Spec.HardError, replyText: String, classId: UInt16, methodId: UInt16)
}

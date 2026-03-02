enum ConnectionError: Error {
    // means that this connection can't be used anymore and should be recreated
    case connectionIsClosed(String)

    // thrown when trying to create more channels than allowed in negotiation
    // (everything can be still used as normal, but new channel can be made only
    // if some are closed)
    case maxChannelsLimitReached

    static let connectionIsClosed = Self.connectionIsClosed("")

    static func wrap(hardError: HardError) -> ConnectionError {
        switch hardError {
        case .broker(let code, let replyText, classId: _, methodId: _):
            return Self.connectionIsClosed("by broker: \(code)\(replyText.isEmpty ? "" : " ")\(replyText)")
        case .client(let code, let replyText, classId: _, methodId: _):
            return Self.connectionIsClosed("by client: \(code)\(replyText.isEmpty ? "" : " ")\(replyText)")
        }
    }
}

// required by tests
extension ConnectionError: Equatable {}

enum ChannelError: Error {
    case channelIsClosed(String)

    static func wrap(softError: SoftError) -> ChannelError {
        switch softError {
        case .broker(let code, let replyText, classId: _, methodId: _):
            return Self.channelIsClosed("by broker: \(code)\(replyText.isEmpty ? "" : " ")\(replyText)")
        case .client(let code, let replyText, classId: _, methodId: _):
            return Self.channelIsClosed("by client: \(code)\(replyText.isEmpty ? "" : " ")\(replyText)")
        }
    }
}

// required by tests
extension ChannelError: Equatable {}

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
    case invalidFrameEnd
    // thrown when the frame doesn't conform to the spec in some way (e.g. expected size is not 0 for method frames)
    case invalidFrame
    case unknownClassAndMethod(class: UInt16, method: UInt16)
    case unknownFrameType(_ type: UInt8)
    case unexpectedNonzeroChannelId(class: UInt16, method: UInt16)
}

// for testing
extension FramingError: Equatable {}

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

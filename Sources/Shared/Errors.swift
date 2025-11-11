enum ConnectionError: Error {
    // means that this connection can't be used anymore and should be recreated
    case connectionIsClosed
    // when this is thrown the connection will be dropped to the server, so one
    // must recreate the Connection object
    case frameSizeLimitExceeded(
        maxFrameSize: UInt32,
        actualSize: UInt32
    )
    // this means that Channel has been closed and should be recreated
    case channelIsClosed
    // thrown when trying to create more channels than allowed in negotiation
    // (everything can be still used as normal, but new channel can be made only
    // if some are closed)
    case maxChannelsLimitReached
}

extension ConnectionError: Equatable {}

enum NegotiationError: Error {
    case protocolVersionMismatch(server: String, client: String)
    case unsupportedAuthMechanism(String)
    /// throws when protocol negotiation is somehow waited on different method from the broker
    case unexpectedMethod
    /// thrown if the frames are not arriving from Server in time of the fixed timeout
    case timedOut
    case unknown
}

enum FramingError: Error {
    case fatal(String)
    case unknownClassAndMethod(class: UInt16, method: UInt16)
    case unknownFrameType(_ type: UInt8)
}

enum TransportError: Error {
}

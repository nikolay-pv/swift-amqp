// required to propagate framing errors from ByteToFrameCoderHandler to
// Connection, as some of them require handshaking the close
enum TransportEvent: Sendable {
    case frame(any Frame)
    case error(FramingError)
}

public struct Configuration: Sendable {
    public var host: String
    public var port: Int

    public enum AuthType: Sendable {
        case basic(username: String, password: String)

        var mechanim: String {
            switch self {
            case .basic: "PLAIN"
            }
        }

        /// returns response as requried by Connection.StartOk method for this type of AuthType
        var response: String {
            switch self {
            case .basic(let username, let password): "\0\(username)\0\(password)"
            }
        }
    }

    public var credentials: AuthType
    public var channelMax: Int = 0
    public var frameMax: Int = 0

    // public var bytesMax: Int {
    //     return max(0, frameMax - AMQP.Spec.FrameHeaderSize - AMQP.Spec.FrameEndSize)
    // }

    public static let `default`: Configuration =
        .init(
            host: "localhost",
            port: 5672,
            credentials: .basic(username: "guest", password: "guest")
        )
}

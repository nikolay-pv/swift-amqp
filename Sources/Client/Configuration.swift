import Logging

public struct Configuration: Sendable {
    public var host: String
    public var port: Int

    public enum AuthType: Sendable {
        case plain(username: String, password: String)
        case external

        var mechanism: String {
            switch self {
            case .plain: "PLAIN"
            case .external: "EXTERNAL"
            }
        }

        /// returns response as required by Connection.StartOk method for this type of AuthType
        var response: String {
            switch self {
            case .plain(let username, let password): "\0\(username)\0\(password)"
            case .external: ""
            }
        }
    }

    public var credentials: AuthType
    public var logger = Logger(label: "swift.amqp")
    public var channelMax: Int = 0
    public var frameMax: Int = 0

    // public var bytesMax: Int {
    //     return max(0, frameMax - AMQP.Spec.FrameHeaderSize - AMQP.Spec.FrameEndSize)
    // }

    public static let `default`: Configuration =
        .init(
            host: "localhost",
            port: 5672,
            credentials: .plain(username: "guest", password: "guest")
        )
}

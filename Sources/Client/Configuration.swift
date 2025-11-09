import Logging

public struct Configuration: Sendable {
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

        mutating func reset() {
            self = .plain(username: "guest", password: "guest")
        }
    }

    public var host: String = "localhost"
    public var port: Int = 5672
    public var vHost: String = "/"

    public var credentials: AuthType = .plain(username: "guest", password: "guest")
    public var maxChannelCount: UInt16 = .max
    // 0 bytes means no limit
    public var maxFrameSize: Int32 = 0

    public enum HeartbeatValue: Sendable, Equatable {
        case disabled
        case serverDefault
        case seconds(UInt16)

        static func make(_ value: UInt16) -> HeartbeatValue {
            guard value == 0 else {
                return .seconds(value)
            }
            return .disabled
        }
    }
    public var heartbeat: HeartbeatValue = .serverDefault

    public var logger = Logger(label: "swift.amqp")

    public static let `default`: Configuration = .init()
}

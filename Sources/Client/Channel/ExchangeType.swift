public enum ExchangeType: Sendable {
    case direct
    case fanout
    case topic
    case headers
    case custom(String)

    public var rawValue: String {
        switch self {
        case .direct:
            return "direct"
        case .fanout:
            return "fanout"
        case .topic:
            return "topic"
        case .headers:
            return "headers"
        case .custom(let value):
            return value
        }
    }
}

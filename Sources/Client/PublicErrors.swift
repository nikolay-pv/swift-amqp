enum PreconditionError: Error, CustomStringConvertible {
    case illegalArgument(String)

    var description: String {
        switch self {
        case .illegalArgument(let message):
            return "Invalid queue name: \(message)"
        }
    }

    static let queueNameTooLong = PreconditionError.illegalArgument("Queue name must not exceed 255 bytes")
}

internal func validate(queueName: String) throws {
    guard queueName.utf8.count <= 255 else {
        throw PreconditionError.queueNameTooLong
    }
}

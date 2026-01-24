enum PreconditionError: Error, CustomStringConvertible {
    case illegalArgument(String)

    var description: String {
        switch self {
        case .illegalArgument(let message):
            return "Invalid queue name: \(message)"
        }
    }

    static let nameTooLong = PreconditionError.illegalArgument("Name must not exceed 255 bytes")
}

internal func validate(shortName name: String) throws {
    guard name.utf8.count < UInt8.max else {
        throw PreconditionError.nameTooLong
    }
}

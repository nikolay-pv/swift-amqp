public struct Message: Sendable {
    public var body: [UInt8]
    public var properties: Spec.BasicProperties
}

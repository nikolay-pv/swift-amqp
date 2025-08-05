public struct Message: Sendable {
    var body: [UInt8]
    var properties: Spec.BasicProperties
}

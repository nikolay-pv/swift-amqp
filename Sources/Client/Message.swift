public struct Message: Sendable {
    public var body: [UInt8]
    public var properties: Spec.BasicProperties
    /// the channel this message was received on
    internal let channel: Channel
    /// delivery tag of the message for ack/nack
    internal let deliveryTag: Int64

    /// Sends ack to the broker.
    /// - Parameter multiple: If true, acknowledges all messages up to and including this one.
    public func ack(multiple: Bool = false) async throws {
        try await channel.basicAck(deliveryTag: deliveryTag, multiple: multiple)
    }

    /// Sends nack to the broker.
    /// - Parameters:
    ///   - multiple: If true, rejects all messages up to and including this one.
    ///   - requeue: If true, the message will be requeued.
    public func nack(requeue: Bool = true, multiple: Bool = false) async throws {
        try await channel.basicNack(deliveryTag: deliveryTag, multiple: multiple, requeue: requeue)
    }
}

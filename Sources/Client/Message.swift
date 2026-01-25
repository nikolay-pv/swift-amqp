public struct Message: Sendable {
    public var body: [UInt8]
    /// consumer tag of the message
    public let consumerTag: String
    /// delivery tag of the message
    public let deliveryTag: Int64
    public let redelivered: Bool = false
    public let exchange: String
    public let routingKey: String
    public var properties: Spec.BasicProperties

    /// the channel this message was received on
    internal let channel: Channel

    /// Sends ack to the broker.
    /// - Parameter multiple: If true, acknowledges all messages up to and including this one.
    ///  - Throws: if connection or this channel has been already closed.
    public func ack(multiple: Bool = false) async throws {
        try await channel.basicAck(deliveryTag: deliveryTag, multiple: multiple)
    }

    /// Sends nack to the broker.
    /// - Parameters:
    ///   - requeue: If true, the message will be requeued.
    ///   - multiple: If true, rejects all messages up to and including this one.
    ///  - Throws: if connection or this channel has been already closed.
    public func nack(requeue: Bool = true, multiple: Bool = false) async throws {
        try await channel.basicNack(deliveryTag: deliveryTag, multiple: multiple, requeue: requeue)
    }

    internal init(
        body: [UInt8],
        deliverFrame: Spec.Basic.Deliver,
        properties: Spec.BasicProperties,
        onChannel channel: Channel
    ) {
        self.body = body
        self.consumerTag = deliverFrame.consumerTag
        self.deliveryTag = deliverFrame.deliveryTag
        self.exchange = deliverFrame.exchange
        self.routingKey = deliverFrame.routingKey
        self.properties = properties
        self.channel = channel
    }
}

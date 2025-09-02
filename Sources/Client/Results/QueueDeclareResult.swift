/// Represents the result of declaring a queue.
public struct QueueDeclareResult: Sendable {
    public let queueName: String
    /// The number of messages in the queue.
    public let messageCount: Int
    /// The number of consumers subscribed to the queue.
    public let consumerCount: Int
}

import AMQP
import Foundation  // UUID
import NIOConcurrencyHelpers  // locks

let sleepDuration = 5
let queueName = "swift-amqp-rpc-queue"

func rpcServer() async throws {
    let connection = try? await Connection(with: .default)
    guard let connection else {
        fatalError("connection wasn't created")
    }
    let channel = try await connection.makeChannel()
    _ = try await channel.queueDeclare(named: queueName)
    print(" [<-] Waiting for messages. To exit press CTRL+C (or send 'stop')")
    let messages = try await channel.basicConsume(queue: queueName)
    for try await message in messages {
        let bodyStr = String(decoding: message.body, as: UTF8.self)
        if bodyStr == "stop" {
            print(" [<-] exiting on 'stop' signal")
            try await message.ack()
            break
        }
        guard let num = Int(bodyStr) else {
            print(" [<-] Received invalid number: \(bodyStr)")
            try await message.nack(requeue: false)
            continue
        }
        let response = String(num * num)
        let responseProperties = Spec.BasicProperties(
            correlationId: message.properties.correlationId
        )
        try await channel.basicPublish(
            exchange: "",
            routingKey: message.properties.replyTo ?? "",
            body: response,
            properties: responseProperties
        )
        print(" [<-] Replied with '\(response)'")
        try await message.ack()
    }
}

let squareServer = Task {
    try await rpcServer()
}

final class SquareClient: Sendable {
    let connection: Connection
    let channel: AMQP.Channel
    let callbackQueue: String
    let responseConsumer: NIOLockedValueBox<Task<Void, any Error>?> = .init(nil)
    let correlationId: NIOLockedValueBox<String> = .init("")
    let response: NIOLockedValueBox<Message?> = .init(nil)

    init() async throws {
        self.connection = try await Connection(with: .default)
        self.channel = try await self.connection.makeChannel()
        let res = try await self.channel.queueDeclare(named: "")
        self.callbackQueue = res.queueName
        let responses = try await self.channel.basicConsume(queue: self.callbackQueue, autoAck: true)
        self.responseConsumer.withLockedValue {
            $0 = Task {
                for try await message in responses {
                    let correlationId = self.correlationId.withLockedValue { $0 }
                    if correlationId == message.properties.correlationId {
                        self.response.withLockedValue { $0 = message }
                    }
                }
            }
        }
    }

    func close() async throws {
        _ = try await self.channel.close()
        _ = try await self.connection.close()
        self.responseConsumer.withLockedValue({ $0?.cancel() })
    }

    func call(n: Int) async throws -> String {
        self.response.withLockedValue { $0 = nil }
        let correlationId = UUID().uuidString
        self.correlationId.withLockedValue { $0 = correlationId }
        let properties = Spec.BasicProperties(
            correlationId: correlationId,
            replyTo: self.callbackQueue
        )
        try await channel.basicPublish(
            exchange: "",
            routingKey: queueName,
            body: String(n),
            properties: properties
        )
        while self.response.withLockedValue({ $0 == nil }) {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let response = self.response.withLockedValue { String(decoding: $0!.body, as: UTF8.self) }
        return response
    }

    func shutdownServer() async {
        try? await self.channel.basicPublish(exchange: "", routingKey: queueName, body: "stop")
    }
}

let client = Task {
    let squareClient = try await SquareClient()
    let numbers = [5, 10, 15, 20, 25, 30]
    for number in numbers {
        let result = try await squareClient.call(n: number)
        print(" [->] Requested square of \(number). Got \(result)")
    }
    // graceful shutdown
    await squareClient.shutdownServer()
    // graceful shutdown
    _ = try await squareClient.close()
}

async let _ = squareServer.result
async let _ = client.result

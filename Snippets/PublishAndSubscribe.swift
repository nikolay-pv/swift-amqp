import AMQP
import Atomics

let sleepDuration = 5
let exchangeName = "swift-amqp-log-exchange"
// used to signal when consumer is ready to receive messages (otherwise
// publisher may send messages before and they will be lost)
var consumersReady: ManagedAtomic<Int> = .init(0)

func receiveLogs(_ label: String) async throws {
    let connection = try? await Connection(with: .default)
    guard let connection else {
        fatalError("connection wasn't created")
    }
    let channel = try await connection.makeChannel()
    _ = try await channel.exchangeDeclare(named: exchangeName, type: .fanout)
    let result = try await channel.queueDeclare(named: "", exclusive: true)
    let queueName = result.queueName
    try await channel.queueBind(queue: queueName, exchange: exchangeName)
    print(" [<-] \(label): Waiting for messages. To exit press CTRL+C")
    await consumersReady.wrappingIncrement(ordering: .releasing)
    let messages = try await channel.basicConsume(queue: queueName, autoAck: true)
    for try await message in messages {
        let bodyStr = String(decoding: message.body, as: UTF8.self)
        print(" [<-] \(label): Received '\(bodyStr)'")
        if bodyStr == "stop" {
            print(" [<-] \(label): exiting on 'stop' signal")
            break
        }
    }
}

let consumer1 = Task {
    try await receiveLogs("Consumer 1")
}

let consumer2 = Task {
    try await receiveLogs("Consumer 2")
}

// Publisher: sends messages without routing key to fanout exchange
let publisher = Task {
    while consumersReady.load(ordering: .acquiring) < 2 {
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
    }
    try await Connection.connectChannelThenClose(with: .default, andProperties: .init()) { result in
        switch result {
        case .success(let channel):
            _ = try await channel.exchangeDeclare(named: exchangeName, type: .fanout)
            let messages = ["info: Hello World!", "warning: about to send stop signal", "stop"]
            for message in messages {
                try await channel.basicPublish(exchange: exchangeName, routingKey: "", body: message)
                print(" [->] Sent '\(message)'")
            }
        case .failure(let error):
            print("Failed to create publisher: \(error)")
        }
    }
}

async let _ = consumer1.result
async let _ = consumer2.result
async let _ = publisher.result

import AMQP
import Atomics

let sleepDuration = 5
let exchangeName = "swift-amqp-topic-log-exchange"
// used to signal when consumer is ready to receive messages (otherwise
// publisher may send messages before and they will be lost)
var consumerReady: ManagedAtomic<Bool> = .init(false)

func receiveLogs(withLevel keys: [String]) async throws {
    precondition(!keys.isEmpty)
    let connection = try? await Connection(with: .default)
    guard let connection else {
        fatalError("connection wasn't created")
    }
    let channel = try await connection.makeChannel()
    _ = try await channel.exchangeDeclare(named: exchangeName, type: .topic)
    let result = try await channel.queueDeclare(named: "", exclusive: true)
    let queueName = result.queueName
    for key in keys {
        try await channel.queueBind(queue: queueName, exchange: exchangeName, routingKey: key)
    }
    print(" [<-] Waiting for messages. To exit press CTRL+C")
    await consumerReady.store(true, ordering: .releasing)
    let messages = try await channel.basicConsume(queue: queueName, autoAck: true)
    for try await message in messages {
        let bodyStr = String(decoding: message.body, as: UTF8.self)
        print(" [<-] Received '\(message.routingKey):\(bodyStr)'")
        if bodyStr == "stop" {
            print(" [<-] exiting on 'stop' signal")
            break
        }
    }
}

let consumer = Task {
    try await receiveLogs(withLevel: ["kern.*", "*.critical"])
}

// Publisher: sends messages with routing key to topic exchange
let publisher = Task {
    while !consumerReady.load(ordering: .acquiring) {
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
    }
    try await Connection.connectChannelThenClose(with: .default, andProperties: .init()) { result in
        switch result {
        case .success(let channel):
            _ = try await channel.exchangeDeclare(named: exchangeName, type: .topic)
            let severities = ["kern.critical", "kern.warning", "kern.fatal"]
            let messages = ["Hello World!", "about to send stop signal", "stop"]
            for (level, message) in zip(severities, messages) {
                try await channel.basicPublish(
                    exchange: exchangeName,
                    routingKey: level,
                    body: message
                )
                print(" [->] Sent '\(level):\(message)'")
            }
        case .failure(let error):
            print("Failed to create publisher: \(error)")
        }
    }
}

async let _ = consumer.result
async let _ = publisher.result

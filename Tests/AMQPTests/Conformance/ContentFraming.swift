import NIOCore
import Testing

@testable import AMQP

@Suite struct ContentFramingConformance {
    static let expectedChannelId: UInt16 = 1
    static let baseActions: [TransportMock.Action] = [
        .outbound(
            MethodFrame(
                channelId: expectedChannelId,
                payload: Spec.Channel.Open()
            )
        ),
        .inbound(
            MethodFrame(
                channelId: expectedChannelId,
                payload: Spec.Channel.OpenOk()
            )
        ),
        .outbound(
            MethodFrame(
                channelId: expectedChannelId,
                payload: AMQP.Spec.Exchange.Declare(
                    exchange: "swift-amqp-exchange",
                    durable: true
                )
            )
        ),
        .inbound(
            MethodFrame(channelId: expectedChannelId, payload: AMQP.Spec.Exchange.DeclareOk())
        ),
        .outbound(
            MethodFrame(
                channelId: expectedChannelId,
                payload: AMQP.Spec.Queue.Declare(
                    queue: "swift-amqp-queue",
                    durable: true
                )
            )
        ),
        .inbound(
            MethodFrame(
                channelId: expectedChannelId,
                payload: AMQP.Spec.Queue.DeclareOk(
                    queue: "swift-amqp-queue",
                    messageCount: 0,
                    consumerCount: 0
                )
            )
        ),
        .outbound(
            MethodFrame(
                channelId: expectedChannelId,
                payload: AMQP.Spec.Queue.Bind(
                    queue: "swift-amqp-queue",
                    exchange: "swift-amqp-exchange",
                    routingKey: "swift-amqp-queue"
                )
            )
        ),
        .inbound(
            MethodFrame(channelId: expectedChannelId, payload: AMQP.Spec.Queue.BindOk())
        ),
        .outbound(
            MethodFrame(
                channelId: expectedChannelId,
                payload: AMQP.Spec.Basic.Consume(
                    queue: "swift-amqp-queue",
                    consumerTag: "some-random-tag"
                )
            )
        ),
        .inbound(
            MethodFrame(
                channelId: expectedChannelId,
                payload: AMQP.Spec.Basic.ConsumeOk(consumerTag: "some-random-tag")
            )
        ),
    ]

    static let interruptedSequence: [TransportMock.Action] = [
        .inbound(
            MethodFrame(
                channelId: expectedChannelId,
                payload: AMQP.Spec.Basic.Deliver(
                    consumerTag: "some-random-tag",
                    deliveryTag: 1,
                    redelivered: false,
                    exchange: "swift-amqp-exchange",
                    routingKey: "swift-amqp-queue"
                )
            )
        ),
        .inbound(
            ContentHeaderFrame(
                channelId: expectedChannelId,
                classId: 60,
                bodySize: 4,
                properties: AMQP.Spec.BasicProperties()
            )
        ),
        // assume that content sequence is interrupted by another frame
        .inbound(
            ContentBodyFrame(channelId: expectedChannelId, fragment: [112, 105])
        ),
        .inbound(
            ContentHeaderFrame(
                channelId: expectedChannelId,
                classId: 60,
                bodySize: 4,
                properties: AMQP.Spec.BasicProperties()
            )
        ),
        .outbound(
            MethodFrame(
                channelId: 0,
                payload: AMQP.Spec.Connection.Close(
                    replyCode: AMQP.Spec.HardError.unexpectedFrame.rawValue,
                    replyText: "Received unexpected frame while waiting for content frames",
                    classId: 60,
                    methodId: 0
                )
            )
        ),
    ]
    static let interruptedSequence2: [TransportMock.Action] = [
        .inbound(
            MethodFrame(
                channelId: expectedChannelId,
                payload: AMQP.Spec.Basic.Deliver(
                    consumerTag: "some-random-tag",
                    deliveryTag: 1,
                    redelivered: false,
                    exchange: "swift-amqp-exchange",
                    routingKey: "swift-amqp-queue"
                )
            )
        ),
        .inbound(
            ContentHeaderFrame(
                channelId: expectedChannelId,
                classId: 60,
                bodySize: 4,
                properties: AMQP.Spec.BasicProperties()
            )
        ),
        // assume that content sequence is interrupted by another frame
        .inbound(
            ContentBodyFrame(channelId: expectedChannelId, fragment: [112, 105])
        ),
        .inbound(
            MethodFrame(
                channelId: expectedChannelId,
                payload:
                    Spec.Basic.Deliver(
                        consumerTag: "tag",
                        deliveryTag: 1,
                        exchange: "exchange",
                        routingKey: "routingKey"
                    )
            )
        ),
        .outbound(
            MethodFrame(
                channelId: 0,
                payload: AMQP.Spec.Connection.Close(
                    replyCode: AMQP.Spec.HardError.unexpectedFrame.rawValue,
                    replyText: "Received unexpected frame while waiting for content frames",
                    classId: 60,
                    methodId: 60
                )
            )
        ),
    ]
    static let skippedDeliver: [TransportMock.Action] = [
        // .inbound(
        //     MethodFrame(
        //         channelId: expectedChannelId,
        //         payload: AMQP.Spec.Basic.Deliver(
        //             consumerTag: "some-random-tag",
        //             deliveryTag: 1,
        //             redelivered: false,
        //             exchange: "swift-amqp-exchange",
        //             routingKey: "swift-amqp-queue"
        //         )
        //     )
        // ),
        .inbound(
            ContentHeaderFrame(
                channelId: expectedChannelId,
                classId: 60,
                bodySize: 4,
                properties: AMQP.Spec.BasicProperties()
            )
        ),
        .outbound(
            MethodFrame(
                channelId: 0,
                payload: AMQP.Spec.Connection.Close(
                    replyCode: AMQP.Spec.HardError.unexpectedFrame.rawValue,
                    replyText: "Received unexpected frame while waiting for content frames",
                    classId: 60,
                    methodId: 0
                )
            )
        ),
    ]
    static let skippedHeader: [TransportMock.Action] = [
        .inbound(
            MethodFrame(
                channelId: expectedChannelId,
                payload: AMQP.Spec.Basic.Deliver(
                    consumerTag: "some-random-tag",
                    deliveryTag: 1,
                    redelivered: false,
                    exchange: "swift-amqp-exchange",
                    routingKey: "swift-amqp-queue"
                )
            )
        ),
        // .inbound(
        //     ContentHeaderFrame(
        //         channelId: expectedChannelId,
        //         classId: 60,
        //         bodySize: 4,
        //         properties: AMQP.Spec.BasicProperties()
        //     )
        // ),
        .inbound(
            ContentBodyFrame(channelId: expectedChannelId, fragment: [112, 105])
        ),
        .outbound(
            MethodFrame(
                channelId: 0,
                payload: AMQP.Spec.Connection.Close(
                    replyCode: AMQP.Spec.HardError.unexpectedFrame.rawValue,
                    replyText: "Received unexpected frame while waiting for content frames",
                    classId: 0,
                    methodId: 0
                )
            )
        ),
    ]

    @Test(
        "4.2.6 an interrupted content sequence",
        arguments: [
            Self.interruptedSequence,
            Self.interruptedSequence2,
            Self.skippedDeliver,
            Self.skippedHeader,
        ]
    )
    func incompleteContentSequence(midActions: [TransportMock.Action]) async throws {
        let actions: [TransportMock.Action] =
            Self.baseActions + midActions + [
                .inbound(
                    MethodFrame(
                        channelId: 0,
                        payload: AMQP.Spec.Connection.CloseOk()
                    )
                )
            ]
        let env = makeTestEnv(with: actions)
        let connection = try await Connection(with: .default, env: env)
        let channel = try await connection.makeChannel()

        #expect(connection.isOpen)
        try await channel.exchangeDeclare(named: "swift-amqp-exchange", durable: true)
        _ = try await channel.queueDeclare(named: "swift-amqp-queue", durable: true)
        try await channel.queueBind(queue: "swift-amqp-queue", exchange: "swift-amqp-exchange")
        let messages = try await channel.basicConsume(
            queue: "swift-amqp-queue",
            tag: "some-random-tag"
        )
        try await #require(
            throws: ConnectionError.connectionIsClosed(
                "by client: unexpectedFrame Received unexpected frame while waiting for content frames"
            )
        ) {
            for try await message in messages {
                _ = message
                break  // safeguard to not loop forever
            }
        }
        #expect(!connection.isOpen)
    }

    static let contentWithInvalidClassId: [TransportMock.Action] = [
        .inbound(
            MethodFrame(
                channelId: expectedChannelId,
                payload: AMQP.Spec.Basic.Deliver(
                    consumerTag: "some-random-tag",
                    deliveryTag: 1,
                    redelivered: false,
                    exchange: "swift-amqp-exchange",
                    routingKey: "swift-amqp-queue"
                )
            )
        ),
        .inbound(
            ContentHeaderFrame(
                channelId: expectedChannelId,
                classId: 30,
                bodySize: 4,
                properties: AMQP.Spec.BasicProperties()
            )
        ),
        .outbound(
            MethodFrame(
                channelId: 0,
                payload: AMQP.Spec.Connection.Close(
                    replyCode: AMQP.Spec.HardError.frameError.rawValue,
                    replyText: "Content frame with unexpected class id",
                    classId: 60,
                    methodId: 0
                )
            )
        ),
    ]

    @Test(
        "4.2.6.1 content frames invalid class id",
        arguments: [
            Self.contentWithInvalidClassId
        ]
    )
    func contentFramesInvalidClassId(midActions: [TransportMock.Action]) async throws {
        let actions: [TransportMock.Action] =
            Self.baseActions + midActions + [
                .inbound(
                    MethodFrame(
                        channelId: 0,
                        payload: AMQP.Spec.Connection.CloseOk()
                    )
                )
            ]
        let env = makeTestEnv(with: actions)
        let connection = try await Connection(with: .default, env: env)
        let channel = try await connection.makeChannel()

        #expect(connection.isOpen)
        try await channel.exchangeDeclare(named: "swift-amqp-exchange", durable: true)
        _ = try await channel.queueDeclare(named: "swift-amqp-queue", durable: true)
        try await channel.queueBind(queue: "swift-amqp-queue", exchange: "swift-amqp-exchange")
        let messages = try await channel.basicConsume(
            queue: "swift-amqp-queue",
            tag: "some-random-tag"
        )
        try await #require(
            throws: ConnectionError.connectionIsClosed(
                "by client: frameError Content frame with unexpected class id"
            )
        ) {
            for try await message in messages {
                _ = message
                break  // safeguard to not loop forever
            }
        }
        #expect(!connection.isOpen)
    }

    static let contentOnChannelZero: [TransportMock.Action] = [
        .inbound(
            MethodFrame(
                channelId: expectedChannelId,
                payload: AMQP.Spec.Basic.Deliver(
                    consumerTag: "some-random-tag",
                    deliveryTag: 1,
                    redelivered: false,
                    exchange: "swift-amqp-exchange",
                    routingKey: "swift-amqp-queue"
                )
            )
        ),
        .inbound(
            ContentHeaderFrame(
                channelId: 0,
                classId: 60,
                bodySize: 4,
                properties: AMQP.Spec.BasicProperties()
            )
        ),
        .outbound(
            MethodFrame(
                channelId: 0,
                payload: AMQP.Spec.Connection.Close(
                    replyCode: AMQP.Spec.HardError.channelError.rawValue,
                    replyText: "Received content frame on channel 0",
                    classId: 60,
                    methodId: 0
                )
            )
        ),
    ]

    @Test(
        "4.2.6.1 content frames at channel 0 protocol violation",
        arguments: [
            Self.contentOnChannelZero
        ]
    )
    func contentFramesAtChannel0ProtocolViolation(midActions: [TransportMock.Action]) async throws {
        let actions: [TransportMock.Action] =
            Self.baseActions + midActions + [
                .inbound(
                    MethodFrame(
                        channelId: 0,
                        payload: AMQP.Spec.Connection.CloseOk()
                    )
                )
            ]
        let env = makeTestEnv(with: actions)
        let connection = try await Connection(with: .default, env: env)
        let channel = try await connection.makeChannel()

        #expect(connection.isOpen)
        try await channel.exchangeDeclare(named: "swift-amqp-exchange", durable: true)
        _ = try await channel.queueDeclare(named: "swift-amqp-queue", durable: true)
        try await channel.queueBind(queue: "swift-amqp-queue", exchange: "swift-amqp-exchange")
        let messages = try await channel.basicConsume(
            queue: "swift-amqp-queue",
            tag: "some-random-tag"
        )
        try await #require(
            throws: ConnectionError.connectionIsClosed(
                "by client: channelError Received content frame on channel 0"
            )
        ) {
            for try await message in messages {
                _ = message
                break  // safeguard to not loop forever
            }
        }
        #expect(!connection.isOpen)
    }
}

import Testing

@testable import AMQP

@Suite struct FramesConformance {

    @Test("4.2.3 Can't receive frames larger the agreed frame size limit")
    func errorOnFramesLargerThanAgreed() async throws {
        let expectedChannelId: UInt16 = 1
        let actions: [TransportMock.Action] = [
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
            // assuming server delivers a frame larger than agreed 3 bytes
            .inbound(
                ContentBodyFrame(channelId: expectedChannelId, fragment: [112, 105, 110, 103])
            ),
            .outbound(
                MethodFrame(
                    channelId: 0,
                    payload: AMQP.Spec.Connection.Close(
                        replyCode: AMQP.Spec.HardError.frameError.rawValue,
                        replyText: "Received ContentBody Frame of size 12 while max size agreed is 3",
                        classId: 60,
                        methodId: 60
                    )
                )
            ),
            .inbound(
                MethodFrame(
                    channelId: 0,
                    payload: AMQP.Spec.Connection.CloseOk()
                )
            ),
        ]
        let env = makeTestEnv(
            with: actions,
            customizingNegotiatedProperties: {
                var (config, props) = $0
                config.maxFrameSize = 3
                return (config, props)
            }
        )
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
                "by client: frameError Received ContentBody Frame of size 12 while max size agreed is 3"
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

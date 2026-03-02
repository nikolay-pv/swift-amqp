import NIOCore
import Testing

@testable import AMQP

@Suite struct GeneralFrameFormatConformance {
    @Test("4.2.3 Can't decode unknown frame types")
    func unknownFrameType() async throws {
        var buffer = ByteBuffer.init(repeating: UInt8.zero, count: 4)
        buffer.setInteger(Spec.frameEnd, at: 3)
        let unknownType: UInt8 = .max
        #expect(throws: FramingError.unknownFrameType(unknownType)) {
            try decodeFrame(type: unknownType, from: buffer)
        }
    }

    @Test("4.2.3 Can't decode frame with unknown ending octet")
    func unknownFrameEnd() async throws {
        let buffer = ByteBuffer.init(repeating: UInt8.zero, count: 3)
        // leave last byte as zero (not Spec.frameEnd)
        #expect(throws: FramingError.invalidFrameEnd) {
            try decodeFrame(type: Spec.frameMethod, from: buffer)
        }
    }

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

    @Test("4.2.7 Heartbeat frames MUST have channel 0")
    func heartbeatMustHaveZeroChannel() async throws {
        let heartbeat = HeartbeatFrame()
        var buffer = try? heartbeat.asData()
        #expect(buffer != nil)
        buffer!.setInteger(UInt16(1), at: 1)  // set non-zero channel
        #expect(throws: FramingError.unexpectedNonzeroChannelId(class: 0, method: 0)) {
            try decodeFrame(type: Spec.frameHeartbeat, from: buffer!)
        }
    }

    @Test("4.2.3 Method frames that refer to Connection class MUST be on channel 0")
    func methodFrameConnectionClassMustBeOnChannelZero() async throws {
        let methods: [any AMQPMethodProtocol & FrameCodable] = [
            AMQP.Spec.Connection.Start(serverProperties: [:]),
            AMQP.Spec.Connection.StartOk(clientProperties: [:], mechanism: "PLAIN", response: ""),
            AMQP.Spec.Connection.Secure(challenge: ""),
            AMQP.Spec.Connection.SecureOk(response: ""),
            AMQP.Spec.Connection.Tune(channelMax: 0, frameMax: 0, heartbeat: 0),
            AMQP.Spec.Connection.TuneOk(channelMax: 0, frameMax: 0, heartbeat: 0),
            AMQP.Spec.Connection.Open(),
            AMQP.Spec.Connection.OpenOk(),
            AMQP.Spec.Connection.Close(replyCode: 0, replyText: "", classId: 0, methodId: 0),
            AMQP.Spec.Connection.CloseOk(),
            AMQP.Spec.Connection.Blocked(),
            AMQP.Spec.Connection.Unblocked(),
            AMQP.Spec.Connection.UpdateSecret(newSecret: "", reason: ""),
            AMQP.Spec.Connection.UpdateSecretOk(),
        ]
        for (i, method) in methods.enumerated() {
            let buffer = try? MethodFrame(channelId: UInt16(i) + 1, payload: method).asData()
            #expect(buffer != nil)
            #expect(
                throws: FramingError.unexpectedNonzeroChannelId(class: method.amqpClassId, method: method.amqpMethodId)
            ) {
                try decodeFrame(type: Spec.frameMethod, from: buffer!)
            }
        }
    }

    @Test("4.2.3 Connection-class frames with non-zero channel cause Close(503)")
    func connectionClassFrameNonZeroChannelTriggersClose() async throws {
        let actions: [TransportMock.Action] = [
            .inboundError(FramingError.unexpectedNonzeroChannelId(class: 10, method: 51)),
            .outbound(
                MethodFrame(
                    channelId: 0,
                    payload: AMQP.Spec.Connection.Close(
                        replyCode: AMQP.Spec.HardError.commandInvalid.rawValue,
                        replyText: "",
                        classId: 10,
                        methodId: 51
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
        let env = makeTestEnv(with: actions)
        let connection = try await Connection(with: .default, env: env)
        try await Task.sleep(for: .milliseconds(100))  // wait for the connection to process the error and react

        #expect(!connection.isOpen)
    }

    @Test(
        "4.2.3 Connection-class frames with non-zero channel cause Close(503)",
        arguments: [
            FramingError.unknownClassAndMethod(class: 10, method: 51),
            .unknownFrameType(100),
            .invalidFrameEnd,
        ]
    )
    func frameEndAndUnknownFrameTypesCauseClose(error: FramingError) async throws {
        let actions: [TransportMock.Action] = [
            .inboundError(error),
            .connectionDrop,
        ]
        let env = makeTestEnv(with: actions)
        let connection = try await Connection(with: .default, env: env)
        try await Task.sleep(for: .milliseconds(100))  // wait for the connection to process the error and react

        #expect(!connection.isOpen)
    }
}

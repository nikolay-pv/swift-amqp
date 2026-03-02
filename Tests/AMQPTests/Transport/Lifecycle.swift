import Logging
import Testing

@testable import AMQP

@Test(
    "Transport can establish connection and stop correctly",
    .tags(.requiresRMQServer),
    .enabled(if: enableSystemTests)
)
func stopTransport() async throws {
    let config = Configuration.default
    var inboundContinuation: AsyncStream<TransportEvent>.Continuation?
    let incomingFrames = AsyncStream { continuation in
        inboundContinuation = continuation
    }
    #expect(inboundContinuation != nil, "AsyncThrowingStream can be constructed")
    let transport = try await Transport(
        host: config.host,
        port: config.port,
        logger: config.logger,
        inboundContinuation: inboundContinuation!,
        negotiatorFactory: {
            Spec.AMQPNegotiator.init(config: config, properties: defaultProperties)
        }
    )
    #expect(transport.isActive, "Transport is usable immediately after construction")
    // ensure graceful shutdown
    transport.sendAsync(
        MethodFrame(channelId: 0, payload: Spec.Connection.Close(replyCode: 0, classId: 0, methodId: 0))
    )
    for await _ in incomingFrames {
        break
    }
    transport.stop()
    #expect(!transport.isActive, "Transport should be inactive after stop() is called")
}

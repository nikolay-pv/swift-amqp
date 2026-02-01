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
    var inboundContinuation: AsyncStream<any Frame>.Continuation?
    let _ = AsyncStream { continuation in
        inboundContinuation = continuation
    }
    #expect(inboundContinuation != nil, "AsyncStream can be constructed")
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
    transport.stop()
    #expect(!transport.isActive, "Transport should be inactive after stop() is called")
}

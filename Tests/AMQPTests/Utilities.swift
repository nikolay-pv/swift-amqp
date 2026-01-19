import Foundation  // for Bundle
import NIOCore

@testable import AMQP

func makeTestEnv(
    with actions: [TransportMock.Action],
    customizingNegotiatedProperties:
        @Sendable @escaping ((Configuration, Spec.Table)) ->
        (Configuration, Spec.Table) = { $0 }
) -> Environment {
    Environment(transportFactory: {
        let transportStub = try await TransportMock(
            host: $0,
            port: $1,
            logger: $2,
            inboundContinuation: $3,
            negotiatorFactory: $4
        )
        transportStub.expecting(sequenceOf: actions)
        var props = transportStub.negotiatedPropertiesShadow
        // disable heartbeat by default in tests
        props.0.heartbeat = .disabled
        transportStub.negotiatedPropertiesShadow = customizingNegotiatedProperties(props)
        return transportStub
    })
}

func fixtureData(
    named fixture: String,
    ofType type: String? = nil,
    inDirectory directory: String? = nil
) throws
    -> ByteBuffer
{
    let path = Bundle.module.path(
        forResource: fixture,
        ofType: type,
        inDirectory: directory,
        forLocalization: nil
    )
    return try .init(string: String(contentsOfFile: path!, encoding: .utf8))
}

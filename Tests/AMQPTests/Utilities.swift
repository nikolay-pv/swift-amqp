import Foundation  // for URL

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

func fixtureData(for fixture: String) throws -> ByteArray {
    try .init(String(contentsOfFile: fixture, encoding: .utf8).utf8)
}

func fixtureUrl(for fixture: String) -> URL {
    fixturesDirectory().appendingPathComponent(fixture)
}

func fixturesDirectory(path: String = #filePath) -> URL {
    let url = URL(fileURLWithPath: path)
    let testsDir = url.deletingLastPathComponent()
    let res = testsDir.appendingPathComponent("Resources", isDirectory: true)
        .appendingPathComponent("Fixtures")
    return res
}

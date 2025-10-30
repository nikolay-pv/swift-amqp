import Foundation

@testable import AMQP

func makeTestEnv(with actions: [TransportMock.Action]) -> Environment {
    var env = Environment.shared
    env.setTransportFactory {
        let transportStub = try await TransportMock(
            host: $0,
            port: $1,
            logger: $2,
            inboundContinuation: $3,
        )
        transportStub.expecting(sequenceOf: actions)
        return transportStub
    }
    return env
}

func fixtureData(for fixture: String) throws -> Data {
    try Data(contentsOf: fixtureUrl(for: fixture))
}

func fixtureUrl(for fixture: String) -> URL {
    fixturesDirectory().appendingPathComponent(fixture)
}

func fixturesDirectory(path: String = #filePath) -> URL {
    let url = URL(fileURLWithPath: path)
    let testsDir = url.deletingLastPathComponent()
    let res = testsDir.appendingPathComponent("Resources").appendingPathComponent("Fixtures")
    return res
}

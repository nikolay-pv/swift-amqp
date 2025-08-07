import Testing

@testable import AMQP  // testable to be able to use TransportProtocol

struct TransportPostNegotiationMock: TransportProtocol, ~Copyable, Sendable {

    enum Action {
        case inbound(any Frame)
        case outbound(any Frame)
    }

    private var outboundFrames: AsyncStream<any Frame>
    private var inboundContinuation: AsyncStream<any Frame>.Continuation
    private(set) var actions: [Action] = .init()

    mutating func expecting(sequenceOf actions: [Action]) {
        self.actions = actions
    }

    // MARK: - TransportProtocol
    init(
        host: String,
        port: Int,
        inboundContinuation: AsyncStream<any AMQP.Frame>.Continuation,
        outboundFrames: AsyncStream<any AMQP.Frame>,
        negotiatorFactory: @escaping @Sendable () -> any AMQP.AMQPNegotiationDelegateProtocol
    ) async throws {
        self.inboundContinuation = inboundContinuation
        self.outboundFrames = outboundFrames
    }

    func sendPending(_ idx: Int) -> Int {
        // send out all inbound actions first to provoke the response
        var idx = idx
        while idx < actions.endIndex {
            guard case .inbound(let frame) = actions[idx] else {
                break
            }
            self.inboundContinuation.yield(frame)
            idx = idx.advanced(by: 1)
        }
        return idx
    }

    func execute() async throws {
        var idx = actions.startIndex
        idx = sendPending(idx)
        if idx == actions.endIndex {
            return
        }
        for try await testedFrame in self.outboundFrames {
            switch actions[idx] {
            case .inbound(let frame):
                self.inboundContinuation.yield(frame)
            case .outbound(let expectedFrame):
                #expect(testedFrame.isEqual(to: expectedFrame))
            }
            idx = idx.advanced(by: 1)
            idx = sendPending(idx)
            if idx == actions.endIndex {
                break
            }
        }
    }
}

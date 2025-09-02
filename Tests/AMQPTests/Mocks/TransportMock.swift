import Logging
import Testing

@testable import AMQP  // testable to be able to use TransportProtocol

struct TransportMock: TransportProtocol, ~Copyable, Sendable {

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
        logger: Logger,
        inboundContinuation: AsyncStream<any AMQP.Frame>.Continuation,
        outboundFrames: AsyncStream<any AMQP.Frame>,
        negotiatorFactory: @escaping @Sendable () -> any AMQP.AMQPNegotiationDelegateProtocol
    ) async throws {
        self.inboundContinuation = inboundContinuation
        self.outboundFrames = outboundFrames
    }

    /// Sends out all inbound actions starting `from` the given index.
    /// Stops at the end of the sequence of `actions` or if outbound frame is encountered.
    ///
    /// - Parameter idx: The starting index for the actions.
    /// - Returns: The new index after sending out all the inbound actions.
    func sendInboundActionsStarting(from idx: Int) -> Int {
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

    func execute() async {
        var idx = actions.startIndex
        idx = sendInboundActionsStarting(from: idx)
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
            idx = sendInboundActionsStarting(from: idx)
            if idx == actions.endIndex {
                break
            }
        }
    }
}

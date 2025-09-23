import Logging
import NIOCore
import NIOPosix
import Testing

@testable import AMQP  // testable to be able to use TransportProtocol

// Warning: this is not strictly sendable
final class TransportMock: TransportProtocol, @unchecked Sendable {

    enum Action {
        case inbound(any Frame)
        case outbound(any Frame)
    }

    private let eventLoop: EventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
    private let outboundContinuation: AsyncStream<any Frame>.Continuation
    private let outboundFrames: AsyncStream<any Frame>
    private let inboundContinuation: AsyncStream<any Frame>.Continuation
    // Warning: the following variable is not Sendable
    private(set) var actions: [Action] = .init()

    func expecting(sequenceOf actions: [Action]) {
        self.actions = actions
    }

    // MARK: - TransportProtocol
    init(
        host: String,
        port: Int,
        logger: Logger,
        inboundContinuation: AsyncStream<any AMQP.Frame>.Continuation,
        negotiatorFactory: @escaping @Sendable () -> any AMQP.AMQPNegotiationDelegateProtocol
    ) async throws {
        self.inboundContinuation = inboundContinuation
        var outboundContinuation: AsyncStream<any Frame>.Continuation?
        self.outboundFrames = AsyncStream { continuation in
            outboundContinuation = continuation
        }
        guard let outboundContinuation else {
            fatalError("Couldn't create outbound AsyncStream")
        }
        // save continuation for later use
        self.outboundContinuation = outboundContinuation
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

extension TransportMock {
    var isActive: Bool { true }

    func send(_ frame: any AMQP.Frame) -> NIOCore.EventLoopPromise<any AMQP.Frame> {
        let promise = eventLoop.makePromise(of: (any Frame).self)
        outboundContinuation.yield(frame)
        return promise
    }

    func send(_ frames: [any AMQP.Frame]) -> NIOCore.EventLoopPromise<any AMQP.Frame> {
        let promise = eventLoop.makePromise(of: (any Frame).self)
        frames.forEach {
            outboundContinuation.yield($0)
        }
        return promise
    }

    func sendAsync(_ frame: any AMQP.Frame) {
        outboundContinuation.yield(frame)
    }

    func sendAsync(_ frames: [any AMQP.Frame]) {
        frames.forEach {
            outboundContinuation.yield($0)
        }
    }
}

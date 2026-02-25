import Atomics
import Logging
import NIOCore
import NIOPosix
import Testing

@testable import AMQP  // testable to be able to use TransportProtocol

// Warning: this is not strictly sendable, make sure that expecting method is executed before MT context
final class TransportMock: TransportProtocol, @unchecked Sendable {

    enum Action {
        case inbound(any Frame)
        case inboundError(FramingError)
        case outbound(any Frame)
        case connectionDrop

        var isConnectionDrop: Bool {
            if case .connectionDrop = self {
                return true
            }
            return false
        }
    }

    private let eventLoop: EventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
    private let outboundContinuation: AsyncStream<any Frame>.Continuation
    private let outboundFrames: AsyncStream<any Frame>
    private let inboundContinuation: AsyncStream<TransportEvent>.Continuation
    // Warning: the following variable is not Sendable
    private(set) var actions: [Action] = .init()
    private(set) var lastUsedIdx: ManagedAtomic<[Action].Index> = .init(0)
    private(set) var connectionWasDropped: ManagedAtomic<Int> = .init(0)

    func expecting(sequenceOf actions: [Action]) {
        self.actions = actions
        self.lastUsedIdx = .init(self.actions.startIndex)
    }

    // MARK: - TransportProtocol
    init(
        host: String,
        port: Int,
        logger: Logger,
        inboundContinuation: AsyncStream<TransportEvent>.Continuation,
        negotiatorFactory: @escaping () -> any AMQPNegotiationDelegateProtocol
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
        Task.detached {
            await self.execute()
        }
    }

    public var negotiatedPropertiesShadow: (Configuration, Spec.Table) = (.default, Spec.Table())

    var negotiatedProperties: (Configuration, Spec.Table) {
        return negotiatedPropertiesShadow
    }

    /// Sends out all inbound actions starting `from` the given index.
    /// Stops at the end of the sequence of `actions` or if outbound frame is encountered.
    ///
    /// - Parameter idx: The starting index for the actions.
    /// - Returns: The new index after sending out all the inbound actions.
    func sendInboundActionsStarting(from idx: Int) -> Int {
        var idx = idx
        while idx < actions.endIndex {
            switch actions[idx] {
            case .inbound(let frame):
                self.inboundContinuation.yield(.frame(frame))
                idx = idx.advanced(by: 1)
                continue
            case .inboundError(let error):
                self.inboundContinuation.yield(.error(error))
                idx = idx.advanced(by: 1)
            case .connectionDrop:
                idx = idx.advanced(by: 1)
            default:
                break
            }
            break
        }
        return idx
    }

    func execute() async {
        var idx = actions.startIndex
        idx = sendInboundActionsStarting(from: idx)
        if idx == actions.endIndex {
            return
        }
        lastUsedIdx.store(idx, ordering: .sequentiallyConsistent)
        for try await testedFrame in self.outboundFrames {
            switch actions[idx] {
            case .inbound(let frame):
                #expect(Bool(false), "Unexpected inbound frame \(frame) at index \(idx)")
            case .inboundError(let error):
                #expect(Bool(false), "Unexpected inbound error \(error) at index \(idx)")
            case .outbound(let expectedFrame):
                #expect(testedFrame.isEqual(to: expectedFrame))
            case .connectionDrop:
                #expect(Bool(false), "Unexpected connection drop at index \(idx)")
            }
            idx = idx.advanced(by: 1)
            idx = sendInboundActionsStarting(from: idx)
            lastUsedIdx.store(idx, ordering: .sequentiallyConsistent)
            if idx == actions.endIndex {
                break
            }
        }
        isActiveShadow.store(false, ordering: .sequentiallyConsistent)
    }

    func drop() {
        connectionWasDropped.wrappingIncrement(by: 1, ordering: .acquiringAndReleasing)
    }

    func stop() {
        self.inboundContinuation.finish()
        self.outboundContinuation.finish()
    }

    var isActiveShadow = ManagedAtomic(true)

    deinit {
        stop()
        var lastUsedIdx = self.lastUsedIdx.load(ordering: .sequentiallyConsistent)
        if lastUsedIdx < actions.endIndex && actions[lastUsedIdx].isConnectionDrop {
            lastUsedIdx = lastUsedIdx.advanced(by: 1)
        }
        if actions.contains(where: { $0.isConnectionDrop }) {
            #expect(
                connectionWasDropped.load(ordering: .sequentiallyConsistent) == 1,
                "Expect connection drop be called once"
            )
        }
        #expect(
            lastUsedIdx == actions.endIndex,
            "Not all expected frames were send/received in TransportMock"
        )
    }
}

extension TransportMock {
    var isActive: Bool {
        return isActiveShadow.load(ordering: .sequentiallyConsistent)
    }

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

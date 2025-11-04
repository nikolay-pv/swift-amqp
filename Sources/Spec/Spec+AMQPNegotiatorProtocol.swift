extension Spec {
    final class AMQPNegotiator {
        enum State {
            case waitingStart
            case waitingSecure
            case waitingTune
            case waitingOpenOk
            case complete
        }

        private var state: State = .waitingStart
        let clientConfig: Configuration
        // will store negotiated configuration here
        var config: Configuration
        let clientProperties: Spec.Table
        var serverProperties: Spec.Table

        init(config: Configuration, properties: Spec.Table) {
            self.clientConfig = config
            self.config = config
            self.clientProperties = properties
            self.serverProperties = [:]
        }
    }
}

extension Spec.AMQPNegotiator {
    fileprivate static func decide<T>(server: T, client: T) -> T where T: Numeric & Comparable {
        if server == 0 || client == 0 {
            return max(server, client)
        }
        return min(server, client)
    }

    fileprivate static func decide(server: UInt16, client: Configuration.HeartbeatValue) -> UInt16 {
        switch client {
        case .serverDefault:
            return server
        case .disabled:
            return 0
        case .seconds(let clientSeconds):
            return min(server, clientSeconds)
        }
    }
}

extension Spec.AMQPNegotiator: AMQPNegotiationDelegateProtocol {
    typealias InputFrame = MethodFrame

    func start() -> TransportAction {
        let header: any Frame = ProtocolHeaderFrame.specHeader
        return .reply(header)
    }

    // swiftlint:disable:next function_body_length
    func negotiate(frame: InputFrame) -> TransportAction {
        switch state {
        case .waitingStart:
            // expected to get Connection.Start
            guard let method = frame.payload as? AMQP.Spec.Connection.Start else {
                return .error(NegotiationError.unexpectedMethod)
            }
            // check protocol versions mismatch
            if method.versionMajor != Spec.ProtocolLevel.MAJOR
                || method.versionMinor != Spec.ProtocolLevel.MINOR
            {
                return .error(
                    NegotiationError.protocolVersionMismatch(
                        server: "\(method.versionMajor).\(method.versionMinor)",
                        client: "\(Spec.ProtocolLevel.MAJOR).\(Spec.ProtocolLevel.MINOR)"
                    )
                )
            }
            // save server information somehow
            // self._set_server_information(method_frame)
            // self._send_connection_start_ok(*self._get_credentials(method_frame))
            if !method.mechanisms.contains(self.clientConfig.credentials.mechanism) {
                let msg =
                    "\(self.clientConfig.credentials.mechanism) is not supported by the server"
                return .error(NegotiationError.unsupportedAuthMechanism(msg))
            }
            self.serverProperties = method.serverProperties
            // send Start-Ok method with selected security mechanism
            let response = AMQP.Spec.Connection.StartOk(
                clientProperties: self.clientProperties,
                mechanism: self.clientConfig.credentials.mechanism,
                response: self.clientConfig.credentials.response
            )
            let startOkFrame = MethodFrame(
                channelId: 0,
                payload: response
            )
            self.state = .waitingTune
            return .reply(startOkFrame)
        case .waitingSecure:
            // repeat below two
            // SASL, challenge-response model = get Secure method
            // send Secure-Ok method
            // then wait on Tune
            fatalError("not implemented")
        case .waitingTune:
            guard let tuneMethod = frame.payload as? AMQP.Spec.Connection.Tune else {
                return .error(NegotiationError.unexpectedMethod)
            }
            // picking correct values
            self.config.maxChannelCount = Self.decide(
                server: tuneMethod.channelMax,
                client: self.clientConfig.maxChannelCount
            )
            self.config.maxFrameSize = Self.decide(
                server: tuneMethod.frameMax,
                client: self.clientConfig.maxFrameSize
            )
            let heartbeat = Self.decide(
                server: tuneMethod.heartbeat,
                client: self.clientConfig.heartbeat
            )
            self.config.heartbeat = Configuration.HeartbeatValue.make(heartbeat)
            let response = AMQP.Spec.Connection.TuneOk(
                channelMax: self.config.maxChannelCount,
                frameMax: self.config.maxFrameSize,
                heartbeat: heartbeat
            )
            let frame = MethodFrame(
                channelId: 0,
                payload: response
            )
            let connectData = MethodFrame(
                channelId: 0,
                payload: Spec.Connection.Open(virtualHost: self.config.vHost, insist: true)
            )
            self.state = .waitingOpenOk
            return .replySeveral([frame, connectData])
        case .waitingOpenOk:
            guard frame.payload is AMQP.Spec.Connection.OpenOk else {
                return .error(NegotiationError.unexpectedMethod)
            }
            self.state = .complete
            return .complete(self.config, self.serverProperties)
        case .complete:
            fatalError("should have been removed from the channel's pipeline")
        }
        fatalError("unreachable")
    }
}

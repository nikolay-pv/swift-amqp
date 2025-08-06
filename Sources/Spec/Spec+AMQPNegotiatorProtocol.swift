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
        var config: Configuration
        let properties: Spec.Table

        init(config: Configuration, properties: Spec.Table) {
            self.config = config
            self.properties = properties
        }
    }
}

extension Spec.AMQPNegotiator {
    fileprivate static func decide(server: Int, client: Int) -> Int {
        if server == 0 || client == 0 {
            return max(server, client)
        }
        return min(server, client)
    }
}

extension Spec.AMQPNegotiator: AMQPNegotiationDelegateProtocol {
    typealias InputFrame = MethodFrame

    func start() -> TransportAction {
        let header: Frame = ProtocolHeaderFrame.specHeader
        return .reply(header)
    }

    func negotiate(frame: InputFrame) -> TransportAction {
        switch state {
        case .waitingStart:
            // TODO: the below would need to be encapsulated somewhere
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
            if !method.mechanisms.contains(self.config.credentials.mechanim) {
                let msg = "\(self.config.credentials.mechanim) is not supported by the server"
                return .error(NegotiationError.unsupportedAuthMechanism(msg))
            }
            // send Start-Ok method with selected security mechanism
            let response = AMQP.Spec.Connection.StartOk(
                // clientProperties: properties,
                clientProperties: ["product": .longstr("pika")],
                mechanism: self.config.credentials.mechanim,
                response: self.config.credentials.response
            )
            let startOkFrame = MethodFrame(
                channelId: 0,
                payload: response
            )
            self.state = .waitingTune
            return .reply(startOkFrame)
        case .waitingSecure:
            // TODO: implement secure
            // repeat below two
            // SASL, challenge-response model = get Secure method
            // send Secure-Ok method
            // then wait on Tune
            fatalError("not implemented")
        case .waitingTune:
            guard let method = frame.payload as? AMQP.Spec.Connection.Tune else {
                return .error(NegotiationError.unexpectedMethod)
            }
            // picking correct values
            self.config.channelMax = Self.decide(
                server: Int(method.channelMax),
                client: self.config.channelMax
            )
            self.config.frameMax = Self.decide(
                server: Int(method.frameMax),
                client: self.config.frameMax
            )
            // TODO: setup hearbeat here
            let response = AMQP.Spec.Connection.TuneOk(
                channelMax: Int16(self.config.channelMax),
                frameMax: Int32(self.config.frameMax),
                heartbeat: 0
            )
            let frame = MethodFrame(
                channelId: 0,
                payload: response
            )
            let connectData = MethodFrame(
                channelId: 0,
                payload: Spec.Connection.Open()  // TODO: config?
            )
            self.state = .waitingOpenOk
            return .replySeveral([frame, connectData])
        case .waitingOpenOk:
            guard frame.payload is AMQP.Spec.Connection.OpenOk else {
                return .error(NegotiationError.unexpectedMethod)
            }
            self.state = .complete
            return .complete
        case .complete:
            fatalError("should have been removed from the channel's pipeline")
        }
        fatalError("unreachable")
    }
}

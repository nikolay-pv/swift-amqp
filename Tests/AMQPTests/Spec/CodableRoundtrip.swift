import Testing

@testable import AMQP

func tester<T>(_ object: T) throws where T: AMQPCodable & Equatable {
    let binary = try FrameEncoder().encode(object)
    let decoded = try FrameDecoder().decode(T.self, from: binary)
    #expect(binary.count == object.bytesCount)
    #expect(decoded == object)
}

@Suite struct BasicCoding {
    @Test("Spec.Basic.Qos default encoding/decoding roundtrip")
    func amqpBasicQosCoding() async throws {
        let object = Spec.Basic.Qos()
        try tester(object)
    }

    @Test("Spec.Basic.QosOk default encoding/decoding roundtrip")
    func amqpBasicQosOkCoding() async throws {
        let object = Spec.Basic.QosOk()
        try tester(object)
    }

    @Test("Spec.Basic.Consume default encoding/decoding roundtrip")
    func amqpBasicConsumeCoding() async throws {
        let object = Spec.Basic.Consume()
        try tester(object)
    }

    @Test("Spec.Basic.ConsumeOk default encoding/decoding roundtrip")
    func amqpBasicConsumeOkCoding() async throws {
        let object = Spec.Basic.ConsumeOk(consumerTag: "FooBar")
        try tester(object)
    }

    @Test("Spec.Basic.Cancel default encoding/decoding roundtrip")
    func amqpBasicCancelCoding() async throws {
        let object = Spec.Basic.Cancel(consumerTag: "FooBar")
        try tester(object)
    }

    @Test("Spec.Basic.CancelOk default encoding/decoding roundtrip")
    func amqpBasicCancelOkCoding() async throws {
        let object = Spec.Basic.CancelOk(consumerTag: "FooBar")
        try tester(object)
    }

    @Test("Spec.Basic.Publish default encoding/decoding roundtrip")
    func amqpBasicPublishCoding() async throws {
        let object = Spec.Basic.Publish()
        try tester(object)
    }

    @Test("Spec.Basic.Return default encoding/decoding roundtrip")
    func amqpBasicReturnCoding() async throws {
        let object = Spec.Basic.Return(replyCode: 1, exchange: "FooBar", routingKey: "FooBar")
        try tester(object)
    }

    @Test("Spec.Basic.Deliver default encoding/decoding roundtrip")
    func amqpBasicDeliverCoding() async throws {
        let object = Spec.Basic.Deliver(
            consumerTag: "FooBar",
            deliveryTag: 1,
            exchange: "FooBar",
            routingKey: "FooBar"
        )
        try tester(object)
    }

    @Test("Spec.Basic.Get default encoding/decoding roundtrip")
    func amqpBasicGetCoding() async throws {
        let object = Spec.Basic.Get()
        try tester(object)
    }

    @Test("Spec.Basic.GetOk default encoding/decoding roundtrip")
    func amqpBasicGetOkCoding() async throws {
        let object = Spec.Basic.GetOk(
            deliveryTag: 1,
            exchange: "FooBar",
            routingKey: "FooBar",
            messageCount: 1
        )
        try tester(object)
    }

    @Test("Spec.Basic.GetEmpty default encoding/decoding roundtrip")
    func amqpBasicGetEmptyCoding() async throws {
        let object = Spec.Basic.GetEmpty()
        try tester(object)
    }

    @Test("Spec.Basic.Ack default encoding/decoding roundtrip")
    func amqpBasicAckCoding() async throws {
        let object = Spec.Basic.Ack()
        try tester(object)
    }

    @Test("Spec.Basic.Reject default encoding/decoding roundtrip")
    func amqpBasicRejectCoding() async throws {
        let object = Spec.Basic.Reject(deliveryTag: 1)
        try tester(object)
    }

    @Test("Spec.Basic.RecoverAsync default encoding/decoding roundtrip")
    func amqpBasicRecoverAsyncCoding() async throws {
        let object = Spec.Basic.RecoverAsync()
        try tester(object)
    }

    @Test("Spec.Basic.Recover default encoding/decoding roundtrip")
    func amqpBasicRecoverCoding() async throws {
        let object = Spec.Basic.Recover()
        try tester(object)
    }

    @Test("Spec.Basic.RecoverOk default encoding/decoding roundtrip")
    func amqpBasicRecoverOkCoding() async throws {
        let object = Spec.Basic.RecoverOk()
        try tester(object)
    }

    @Test("Spec.Basic.Nack default encoding/decoding roundtrip")
    func amqpBasicNackCoding() async throws {
        let object = Spec.Basic.Nack()
        try tester(object)
    }

}

@Suite struct ConnectionCoding {
    @Test("Spec.Connection.Start default encoding/decoding roundtrip")
    func amqpConnectionStartCoding() async throws {
        let object = Spec.Connection.Start(serverProperties: .init())
        try tester(object)
    }

    @Test("Spec.Connection.StartOk default encoding/decoding roundtrip")
    func amqpConnectionStartOkCoding() async throws {
        let object = Spec.Connection.StartOk(clientProperties: .init(), response: "FooBar")
        try tester(object)
    }

    @Test("Spec.Connection.Secure default encoding/decoding roundtrip")
    func amqpConnectionSecureCoding() async throws {
        let object = Spec.Connection.Secure(challenge: "FooBar")
        try tester(object)
    }

    @Test("Spec.Connection.SecureOk default encoding/decoding roundtrip")
    func amqpConnectionSecureOkCoding() async throws {
        let object = Spec.Connection.SecureOk(response: "FooBar")
        try tester(object)
    }

    @Test("Spec.Connection.Tune default encoding/decoding roundtrip")
    func amqpConnectionTuneCoding() async throws {
        let object = Spec.Connection.Tune()
        try tester(object)
    }

    @Test("Spec.Connection.TuneOk default encoding/decoding roundtrip")
    func amqpConnectionTuneOkCoding() async throws {
        let object = Spec.Connection.TuneOk()
        try tester(object)
    }

    @Test("Spec.Connection.Open default encoding/decoding roundtrip")
    func amqpConnectionOpenCoding() async throws {
        let object = Spec.Connection.Open()
        try tester(object)
    }

    @Test("Spec.Connection.OpenOk default encoding/decoding roundtrip")
    func amqpConnectionOpenOkCoding() async throws {
        let object = Spec.Connection.OpenOk()
        try tester(object)
    }

    @Test("Spec.Connection.Close default encoding/decoding roundtrip")
    func amqpConnectionCloseCoding() async throws {
        let object = Spec.Connection.Close(replyCode: 1, classId: 1, methodId: 1)
        try tester(object)
    }

    @Test("Spec.Connection.CloseOk default encoding/decoding roundtrip")
    func amqpConnectionCloseOkCoding() async throws {
        let object = Spec.Connection.CloseOk()
        try tester(object)
    }

    @Test("Spec.Connection.Blocked default encoding/decoding roundtrip")
    func amqpConnectionBlockedCoding() async throws {
        let object = Spec.Connection.Blocked()
        try tester(object)
    }

    @Test("Spec.Connection.Unblocked default encoding/decoding roundtrip")
    func amqpConnectionUnblockedCoding() async throws {
        let object = Spec.Connection.Unblocked()
        try tester(object)
    }

    @Test("Spec.Connection.UpdateSecret default encoding/decoding roundtrip")
    func amqpConnectionUpdateSecretCoding() async throws {
        let object = Spec.Connection.UpdateSecret(newSecret: "FooBar", reason: "FooBar")
        try tester(object)
    }

    @Test("Spec.Connection.UpdateSecretOk default encoding/decoding roundtrip")
    func amqpConnectionUpdateSecretOkCoding() async throws {
        let object = Spec.Connection.UpdateSecretOk()
        try tester(object)
    }

}

@Suite struct ChannelCoding {
    @Test("Spec.Channel.Open default encoding/decoding roundtrip")
    func amqpChannelOpenCoding() async throws {
        let object = Spec.Channel.Open()
        try tester(object)
    }

    @Test("Spec.Channel.OpenOk default encoding/decoding roundtrip")
    func amqpChannelOpenOkCoding() async throws {
        let object = Spec.Channel.OpenOk()
        try tester(object)
    }

    @Test("Spec.Channel.Flow default encoding/decoding roundtrip")
    func amqpChannelFlowCoding() async throws {
        let object = Spec.Channel.Flow(active: true)
        try tester(object)
    }

    @Test("Spec.Channel.FlowOk default encoding/decoding roundtrip")
    func amqpChannelFlowOkCoding() async throws {
        let object = Spec.Channel.FlowOk(active: true)
        try tester(object)
    }

    @Test("Spec.Channel.Close default encoding/decoding roundtrip")
    func amqpChannelCloseCoding() async throws {
        let object = Spec.Channel.Close(replyCode: 1, classId: 1, methodId: 1)
        try tester(object)
    }

    @Test("Spec.Channel.CloseOk default encoding/decoding roundtrip")
    func amqpChannelCloseOkCoding() async throws {
        let object = Spec.Channel.CloseOk()
        try tester(object)
    }

}

@Suite struct AccessCoding {
    @Test("Spec.Access.Request default encoding/decoding roundtrip")
    func amqpAccessRequestCoding() async throws {
        let object = Spec.Access.Request()
        try tester(object)
    }

    @Test("Spec.Access.RequestOk default encoding/decoding roundtrip")
    func amqpAccessRequestOkCoding() async throws {
        let object = Spec.Access.RequestOk()
        try tester(object)
    }

}

@Suite struct ExchangeCoding {
    @Test("Spec.Exchange.Declare default encoding/decoding roundtrip")
    func amqpExchangeDeclareCoding() async throws {
        let object = Spec.Exchange.Declare(exchange: "FooBar")
        try tester(object)
    }

    @Test("Spec.Exchange.DeclareOk default encoding/decoding roundtrip")
    func amqpExchangeDeclareOkCoding() async throws {
        let object = Spec.Exchange.DeclareOk()
        try tester(object)
    }

    @Test("Spec.Exchange.Delete default encoding/decoding roundtrip")
    func amqpExchangeDeleteCoding() async throws {
        let object = Spec.Exchange.Delete(exchange: "FooBar")
        try tester(object)
    }

    @Test("Spec.Exchange.DeleteOk default encoding/decoding roundtrip")
    func amqpExchangeDeleteOkCoding() async throws {
        let object = Spec.Exchange.DeleteOk()
        try tester(object)
    }

    @Test("Spec.Exchange.Bind default encoding/decoding roundtrip")
    func amqpExchangeBindCoding() async throws {
        let object = Spec.Exchange.Bind(destination: "FooBar", source: "FooBar")
        try tester(object)
    }

    @Test("Spec.Exchange.BindOk default encoding/decoding roundtrip")
    func amqpExchangeBindOkCoding() async throws {
        let object = Spec.Exchange.BindOk()
        try tester(object)
    }

    @Test("Spec.Exchange.Unbind default encoding/decoding roundtrip")
    func amqpExchangeUnbindCoding() async throws {
        let object = Spec.Exchange.Unbind(destination: "FooBar", source: "FooBar")
        try tester(object)
    }

    @Test("Spec.Exchange.UnbindOk default encoding/decoding roundtrip")
    func amqpExchangeUnbindOkCoding() async throws {
        let object = Spec.Exchange.UnbindOk()
        try tester(object)
    }

}

@Suite struct QueueCoding {
    @Test("Spec.Queue.Declare default encoding/decoding roundtrip")
    func amqpQueueDeclareCoding() async throws {
        let object = Spec.Queue.Declare()
        try tester(object)
    }

    @Test("Spec.Queue.DeclareOk default encoding/decoding roundtrip")
    func amqpQueueDeclareOkCoding() async throws {
        let object = Spec.Queue.DeclareOk(queue: "FooBar", messageCount: 1, consumerCount: 1)
        try tester(object)
    }

    @Test("Spec.Queue.Bind default encoding/decoding roundtrip")
    func amqpQueueBindCoding() async throws {
        let object = Spec.Queue.Bind(exchange: "FooBar")
        try tester(object)
    }

    @Test("Spec.Queue.BindOk default encoding/decoding roundtrip")
    func amqpQueueBindOkCoding() async throws {
        let object = Spec.Queue.BindOk()
        try tester(object)
    }

    @Test("Spec.Queue.Purge default encoding/decoding roundtrip")
    func amqpQueuePurgeCoding() async throws {
        let object = Spec.Queue.Purge()
        try tester(object)
    }

    @Test("Spec.Queue.PurgeOk default encoding/decoding roundtrip")
    func amqpQueuePurgeOkCoding() async throws {
        let object = Spec.Queue.PurgeOk(messageCount: 1)
        try tester(object)
    }

    @Test("Spec.Queue.Delete default encoding/decoding roundtrip")
    func amqpQueueDeleteCoding() async throws {
        let object = Spec.Queue.Delete()
        try tester(object)
    }

    @Test("Spec.Queue.DeleteOk default encoding/decoding roundtrip")
    func amqpQueueDeleteOkCoding() async throws {
        let object = Spec.Queue.DeleteOk(messageCount: 1)
        try tester(object)
    }

    @Test("Spec.Queue.Unbind default encoding/decoding roundtrip")
    func amqpQueueUnbindCoding() async throws {
        let object = Spec.Queue.Unbind(exchange: "FooBar")
        try tester(object)
    }

    @Test("Spec.Queue.UnbindOk default encoding/decoding roundtrip")
    func amqpQueueUnbindOkCoding() async throws {
        let object = Spec.Queue.UnbindOk()
        try tester(object)
    }

}

@Suite struct TxCoding {
    @Test("Spec.Tx.Select default encoding/decoding roundtrip")
    func amqpTxSelectCoding() async throws {
        let object = Spec.Tx.Select()
        try tester(object)
    }

    @Test("Spec.Tx.SelectOk default encoding/decoding roundtrip")
    func amqpTxSelectOkCoding() async throws {
        let object = Spec.Tx.SelectOk()
        try tester(object)
    }

    @Test("Spec.Tx.Commit default encoding/decoding roundtrip")
    func amqpTxCommitCoding() async throws {
        let object = Spec.Tx.Commit()
        try tester(object)
    }

    @Test("Spec.Tx.CommitOk default encoding/decoding roundtrip")
    func amqpTxCommitOkCoding() async throws {
        let object = Spec.Tx.CommitOk()
        try tester(object)
    }

    @Test("Spec.Tx.Rollback default encoding/decoding roundtrip")
    func amqpTxRollbackCoding() async throws {
        let object = Spec.Tx.Rollback()
        try tester(object)
    }

    @Test("Spec.Tx.RollbackOk default encoding/decoding roundtrip")
    func amqpTxRollbackOkCoding() async throws {
        let object = Spec.Tx.RollbackOk()
        try tester(object)
    }

}

@Suite struct ConfirmCoding {
    @Test("Spec.Confirm.Select default encoding/decoding roundtrip")
    func amqpConfirmSelectCoding() async throws {
        let object = Spec.Confirm.Select()
        try tester(object)
    }

    @Test("Spec.Confirm.SelectOk default encoding/decoding roundtrip")
    func amqpConfirmSelectOkCoding() async throws {
        let object = Spec.Confirm.SelectOk()
        try tester(object)
    }

}

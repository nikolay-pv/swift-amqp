import Testing

@testable import AMQP

func tester<T>(_ object: T) throws where T: AMQPCodable & Equatable {
    let binary = try FrameEncoder().encode(object)
    let decoded = try FrameDecoder().decode(T.self, from: binary)
    #expect(decoded == object)
}

@Suite struct BasicCoding {
    @Test("AMQP.Basic.Qos default encoding/decoding roundtrip")
    func amqpBasicQosCoding() async throws {
        let object = AMQP.Basic.Qos()
        try tester(object)
    }

    @Test("AMQP.Basic.QosOk default encoding/decoding roundtrip")
    func amqpBasicQosOkCoding() async throws {
        let object = AMQP.Basic.QosOk()
        try tester(object)
    }

    @Test("AMQP.Basic.Consume default encoding/decoding roundtrip")
    func amqpBasicConsumeCoding() async throws {
        let object = AMQP.Basic.Consume()
        try tester(object)
    }

    @Test("AMQP.Basic.ConsumeOk default encoding/decoding roundtrip")
    func amqpBasicConsumeOkCoding() async throws {
        let object = AMQP.Basic.ConsumeOk(consumerTag: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Basic.Cancel default encoding/decoding roundtrip")
    func amqpBasicCancelCoding() async throws {
        let object = AMQP.Basic.Cancel(consumerTag: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Basic.CancelOk default encoding/decoding roundtrip")
    func amqpBasicCancelOkCoding() async throws {
        let object = AMQP.Basic.CancelOk(consumerTag: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Basic.Publish default encoding/decoding roundtrip")
    func amqpBasicPublishCoding() async throws {
        let object = AMQP.Basic.Publish()
        try tester(object)
    }

    @Test("AMQP.Basic.Return default encoding/decoding roundtrip")
    func amqpBasicReturnCoding() async throws {
        let object = AMQP.Basic.Return(replyCode: 1, exchange: "FooBar", routingKey: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Basic.Deliver default encoding/decoding roundtrip")
    func amqpBasicDeliverCoding() async throws {
        let object = AMQP.Basic.Deliver(
            consumerTag: "FooBar",
            deliveryTag: 1,
            exchange: "FooBar",
            routingKey: "FooBar"
        )
        try tester(object)
    }

    @Test("AMQP.Basic.Get default encoding/decoding roundtrip")
    func amqpBasicGetCoding() async throws {
        let object = AMQP.Basic.Get()
        try tester(object)
    }

    @Test("AMQP.Basic.GetOk default encoding/decoding roundtrip")
    func amqpBasicGetOkCoding() async throws {
        let object = AMQP.Basic.GetOk(
            deliveryTag: 1,
            exchange: "FooBar",
            routingKey: "FooBar",
            messageCount: 1
        )
        try tester(object)
    }

    @Test("AMQP.Basic.GetEmpty default encoding/decoding roundtrip")
    func amqpBasicGetEmptyCoding() async throws {
        let object = AMQP.Basic.GetEmpty()
        try tester(object)
    }

    @Test("AMQP.Basic.Ack default encoding/decoding roundtrip")
    func amqpBasicAckCoding() async throws {
        let object = AMQP.Basic.Ack()
        try tester(object)
    }

    @Test("AMQP.Basic.Reject default encoding/decoding roundtrip")
    func amqpBasicRejectCoding() async throws {
        let object = AMQP.Basic.Reject(deliveryTag: 1)
        try tester(object)
    }

    @Test("AMQP.Basic.RecoverAsync default encoding/decoding roundtrip")
    func amqpBasicRecoverAsyncCoding() async throws {
        let object = AMQP.Basic.RecoverAsync()
        try tester(object)
    }

    @Test("AMQP.Basic.Recover default encoding/decoding roundtrip")
    func amqpBasicRecoverCoding() async throws {
        let object = AMQP.Basic.Recover()
        try tester(object)
    }

    @Test("AMQP.Basic.RecoverOk default encoding/decoding roundtrip")
    func amqpBasicRecoverOkCoding() async throws {
        let object = AMQP.Basic.RecoverOk()
        try tester(object)
    }

    @Test("AMQP.Basic.Nack default encoding/decoding roundtrip")
    func amqpBasicNackCoding() async throws {
        let object = AMQP.Basic.Nack()
        try tester(object)
    }

}

@Suite struct ConnectionCoding {
    @Test("AMQP.Connection.Start default encoding/decoding roundtrip")
    func amqpConnectionStartCoding() async throws {
        let object = AMQP.Connection.Start(serverProperties: .init())
        try tester(object)
    }

    @Test("AMQP.Connection.StartOk default encoding/decoding roundtrip")
    func amqpConnectionStartOkCoding() async throws {
        let object = AMQP.Connection.StartOk(clientProperties: .init(), response: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Connection.Secure default encoding/decoding roundtrip")
    func amqpConnectionSecureCoding() async throws {
        let object = AMQP.Connection.Secure(challenge: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Connection.SecureOk default encoding/decoding roundtrip")
    func amqpConnectionSecureOkCoding() async throws {
        let object = AMQP.Connection.SecureOk(response: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Connection.Tune default encoding/decoding roundtrip")
    func amqpConnectionTuneCoding() async throws {
        let object = AMQP.Connection.Tune()
        try tester(object)
    }

    @Test("AMQP.Connection.TuneOk default encoding/decoding roundtrip")
    func amqpConnectionTuneOkCoding() async throws {
        let object = AMQP.Connection.TuneOk()
        try tester(object)
    }

    @Test("AMQP.Connection.Open default encoding/decoding roundtrip")
    func amqpConnectionOpenCoding() async throws {
        let object = AMQP.Connection.Open()
        try tester(object)
    }

    @Test("AMQP.Connection.OpenOk default encoding/decoding roundtrip")
    func amqpConnectionOpenOkCoding() async throws {
        let object = AMQP.Connection.OpenOk()
        try tester(object)
    }

    @Test("AMQP.Connection.Close default encoding/decoding roundtrip")
    func amqpConnectionCloseCoding() async throws {
        let object = AMQP.Connection.Close(replyCode: 1, classId: 1, methodId: 1)
        try tester(object)
    }

    @Test("AMQP.Connection.CloseOk default encoding/decoding roundtrip")
    func amqpConnectionCloseOkCoding() async throws {
        let object = AMQP.Connection.CloseOk()
        try tester(object)
    }

    @Test("AMQP.Connection.Blocked default encoding/decoding roundtrip")
    func amqpConnectionBlockedCoding() async throws {
        let object = AMQP.Connection.Blocked()
        try tester(object)
    }

    @Test("AMQP.Connection.Unblocked default encoding/decoding roundtrip")
    func amqpConnectionUnblockedCoding() async throws {
        let object = AMQP.Connection.Unblocked()
        try tester(object)
    }

    @Test("AMQP.Connection.UpdateSecret default encoding/decoding roundtrip")
    func amqpConnectionUpdateSecretCoding() async throws {
        let object = AMQP.Connection.UpdateSecret(newSecret: "FooBar", reason: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Connection.UpdateSecretOk default encoding/decoding roundtrip")
    func amqpConnectionUpdateSecretOkCoding() async throws {
        let object = AMQP.Connection.UpdateSecretOk()
        try tester(object)
    }

}

@Suite struct ChannelCoding {
    @Test("AMQP.Channel.Open default encoding/decoding roundtrip")
    func amqpChannelOpenCoding() async throws {
        let object = AMQP.Channel.Open()
        try tester(object)
    }

    @Test("AMQP.Channel.OpenOk default encoding/decoding roundtrip")
    func amqpChannelOpenOkCoding() async throws {
        let object = AMQP.Channel.OpenOk()
        try tester(object)
    }

    @Test("AMQP.Channel.Flow default encoding/decoding roundtrip")
    func amqpChannelFlowCoding() async throws {
        let object = AMQP.Channel.Flow(active: true)
        try tester(object)
    }

    @Test("AMQP.Channel.FlowOk default encoding/decoding roundtrip")
    func amqpChannelFlowOkCoding() async throws {
        let object = AMQP.Channel.FlowOk(active: true)
        try tester(object)
    }

    @Test("AMQP.Channel.Close default encoding/decoding roundtrip")
    func amqpChannelCloseCoding() async throws {
        let object = AMQP.Channel.Close(replyCode: 1, classId: 1, methodId: 1)
        try tester(object)
    }

    @Test("AMQP.Channel.CloseOk default encoding/decoding roundtrip")
    func amqpChannelCloseOkCoding() async throws {
        let object = AMQP.Channel.CloseOk()
        try tester(object)
    }

}

@Suite struct AccessCoding {
    @Test("AMQP.Access.Request default encoding/decoding roundtrip")
    func amqpAccessRequestCoding() async throws {
        let object = AMQP.Access.Request()
        try tester(object)
    }

    @Test("AMQP.Access.RequestOk default encoding/decoding roundtrip")
    func amqpAccessRequestOkCoding() async throws {
        let object = AMQP.Access.RequestOk()
        try tester(object)
    }

}

@Suite struct ExchangeCoding {
    @Test("AMQP.Exchange.Declare default encoding/decoding roundtrip")
    func amqpExchangeDeclareCoding() async throws {
        let object = AMQP.Exchange.Declare(exchange: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Exchange.DeclareOk default encoding/decoding roundtrip")
    func amqpExchangeDeclareOkCoding() async throws {
        let object = AMQP.Exchange.DeclareOk()
        try tester(object)
    }

    @Test("AMQP.Exchange.Delete default encoding/decoding roundtrip")
    func amqpExchangeDeleteCoding() async throws {
        let object = AMQP.Exchange.Delete(exchange: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Exchange.DeleteOk default encoding/decoding roundtrip")
    func amqpExchangeDeleteOkCoding() async throws {
        let object = AMQP.Exchange.DeleteOk()
        try tester(object)
    }

    @Test("AMQP.Exchange.Bind default encoding/decoding roundtrip")
    func amqpExchangeBindCoding() async throws {
        let object = AMQP.Exchange.Bind(destination: "FooBar", source: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Exchange.BindOk default encoding/decoding roundtrip")
    func amqpExchangeBindOkCoding() async throws {
        let object = AMQP.Exchange.BindOk()
        try tester(object)
    }

    @Test("AMQP.Exchange.Unbind default encoding/decoding roundtrip")
    func amqpExchangeUnbindCoding() async throws {
        let object = AMQP.Exchange.Unbind(destination: "FooBar", source: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Exchange.UnbindOk default encoding/decoding roundtrip")
    func amqpExchangeUnbindOkCoding() async throws {
        let object = AMQP.Exchange.UnbindOk()
        try tester(object)
    }

}

@Suite struct QueueCoding {
    @Test("AMQP.Queue.Declare default encoding/decoding roundtrip")
    func amqpQueueDeclareCoding() async throws {
        let object = AMQP.Queue.Declare()
        try tester(object)
    }

    @Test("AMQP.Queue.DeclareOk default encoding/decoding roundtrip")
    func amqpQueueDeclareOkCoding() async throws {
        let object = AMQP.Queue.DeclareOk(queue: "FooBar", messageCount: 1, consumerCount: 1)
        try tester(object)
    }

    @Test("AMQP.Queue.Bind default encoding/decoding roundtrip")
    func amqpQueueBindCoding() async throws {
        let object = AMQP.Queue.Bind(exchange: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Queue.BindOk default encoding/decoding roundtrip")
    func amqpQueueBindOkCoding() async throws {
        let object = AMQP.Queue.BindOk()
        try tester(object)
    }

    @Test("AMQP.Queue.Purge default encoding/decoding roundtrip")
    func amqpQueuePurgeCoding() async throws {
        let object = AMQP.Queue.Purge()
        try tester(object)
    }

    @Test("AMQP.Queue.PurgeOk default encoding/decoding roundtrip")
    func amqpQueuePurgeOkCoding() async throws {
        let object = AMQP.Queue.PurgeOk(messageCount: 1)
        try tester(object)
    }

    @Test("AMQP.Queue.Delete default encoding/decoding roundtrip")
    func amqpQueueDeleteCoding() async throws {
        let object = AMQP.Queue.Delete()
        try tester(object)
    }

    @Test("AMQP.Queue.DeleteOk default encoding/decoding roundtrip")
    func amqpQueueDeleteOkCoding() async throws {
        let object = AMQP.Queue.DeleteOk(messageCount: 1)
        try tester(object)
    }

    @Test("AMQP.Queue.Unbind default encoding/decoding roundtrip")
    func amqpQueueUnbindCoding() async throws {
        let object = AMQP.Queue.Unbind(exchange: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Queue.UnbindOk default encoding/decoding roundtrip")
    func amqpQueueUnbindOkCoding() async throws {
        let object = AMQP.Queue.UnbindOk()
        try tester(object)
    }

}

@Suite struct TxCoding {
    @Test("AMQP.Tx.Select default encoding/decoding roundtrip")
    func amqpTxSelectCoding() async throws {
        let object = AMQP.Tx.Select()
        try tester(object)
    }

    @Test("AMQP.Tx.SelectOk default encoding/decoding roundtrip")
    func amqpTxSelectOkCoding() async throws {
        let object = AMQP.Tx.SelectOk()
        try tester(object)
    }

    @Test("AMQP.Tx.Commit default encoding/decoding roundtrip")
    func amqpTxCommitCoding() async throws {
        let object = AMQP.Tx.Commit()
        try tester(object)
    }

    @Test("AMQP.Tx.CommitOk default encoding/decoding roundtrip")
    func amqpTxCommitOkCoding() async throws {
        let object = AMQP.Tx.CommitOk()
        try tester(object)
    }

    @Test("AMQP.Tx.Rollback default encoding/decoding roundtrip")
    func amqpTxRollbackCoding() async throws {
        let object = AMQP.Tx.Rollback()
        try tester(object)
    }

    @Test("AMQP.Tx.RollbackOk default encoding/decoding roundtrip")
    func amqpTxRollbackOkCoding() async throws {
        let object = AMQP.Tx.RollbackOk()
        try tester(object)
    }

}

@Suite struct ConfirmCoding {
    @Test("AMQP.Confirm.Select default encoding/decoding roundtrip")
    func amqpConfirmSelectCoding() async throws {
        let object = AMQP.Confirm.Select()
        try tester(object)
    }

    @Test("AMQP.Confirm.SelectOk default encoding/decoding roundtrip")
    func amqpConfirmSelectOkCoding() async throws {
        let object = AMQP.Confirm.SelectOk()
        try tester(object)
    }

}

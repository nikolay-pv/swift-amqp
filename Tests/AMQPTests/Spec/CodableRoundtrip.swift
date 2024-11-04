import Testing
@testable import AMQP

func tester<T>(_ object: T) throws where T : AMQPCodable & Equatable {
    let binary = try FrameEncoder().encode(object)
    let decoded = try FrameDecoder().decode(T.self, from: binary)
    #expect(decoded == object)
}

@Suite struct Basic {
    @Test("AMQP.Basic.Qos default encoding/decoding roundtrip")
    func amqpBasicQosEncoding() async throws {
        let object = AMQP.Basic.Qos()
        try tester(object)
    }

    @Test("AMQP.Basic.QosOk default encoding/decoding roundtrip")
    func amqpBasicQosOkEncoding() async throws {
        let object = AMQP.Basic.QosOk()
        try tester(object)
    }

    @Test("AMQP.Basic.Consume default encoding/decoding roundtrip")
    func amqpBasicConsumeEncoding() async throws {
        let object = AMQP.Basic.Consume()
        try tester(object)
    }

    @Test("AMQP.Basic.ConsumeOk default encoding/decoding roundtrip")
    func amqpBasicConsumeOkEncoding() async throws {
        let object = AMQP.Basic.ConsumeOk(consumerTag: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Basic.Cancel default encoding/decoding roundtrip")
    func amqpBasicCancelEncoding() async throws {
        let object = AMQP.Basic.Cancel(consumerTag: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Basic.CancelOk default encoding/decoding roundtrip")
    func amqpBasicCancelOkEncoding() async throws {
        let object = AMQP.Basic.CancelOk(consumerTag: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Basic.Publish default encoding/decoding roundtrip")
    func amqpBasicPublishEncoding() async throws {
        let object = AMQP.Basic.Publish()
        try tester(object)
    }

    @Test("AMQP.Basic.Return default encoding/decoding roundtrip")
    func amqpBasicReturnEncoding() async throws {
        let object = AMQP.Basic.Return(replyCode: 1, exchange: "FooBar", routingKey: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Basic.Deliver default encoding/decoding roundtrip")
    func amqpBasicDeliverEncoding() async throws {
        let object = AMQP.Basic.Deliver(consumerTag: "FooBar", deliveryTag: 1, exchange: "FooBar", routingKey: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Basic.Get default encoding/decoding roundtrip")
    func amqpBasicGetEncoding() async throws {
        let object = AMQP.Basic.Get()
        try tester(object)
    }

    @Test("AMQP.Basic.GetOk default encoding/decoding roundtrip")
    func amqpBasicGetOkEncoding() async throws {
        let object = AMQP.Basic.GetOk(deliveryTag: 1, exchange: "FooBar", routingKey: "FooBar", messageCount: 1)
        try tester(object)
    }

    @Test("AMQP.Basic.GetEmpty default encoding/decoding roundtrip")
    func amqpBasicGetEmptyEncoding() async throws {
        let object = AMQP.Basic.GetEmpty()
        try tester(object)
    }

    @Test("AMQP.Basic.Ack default encoding/decoding roundtrip")
    func amqpBasicAckEncoding() async throws {
        let object = AMQP.Basic.Ack()
        try tester(object)
    }

    @Test("AMQP.Basic.Reject default encoding/decoding roundtrip")
    func amqpBasicRejectEncoding() async throws {
        let object = AMQP.Basic.Reject(deliveryTag: 1)
        try tester(object)
    }

    @Test("AMQP.Basic.RecoverAsync default encoding/decoding roundtrip")
    func amqpBasicRecoverAsyncEncoding() async throws {
        let object = AMQP.Basic.RecoverAsync()
        try tester(object)
    }

    @Test("AMQP.Basic.Recover default encoding/decoding roundtrip")
    func amqpBasicRecoverEncoding() async throws {
        let object = AMQP.Basic.Recover()
        try tester(object)
    }

    @Test("AMQP.Basic.RecoverOk default encoding/decoding roundtrip")
    func amqpBasicRecoverOkEncoding() async throws {
        let object = AMQP.Basic.RecoverOk()
        try tester(object)
    }

    @Test("AMQP.Basic.Nack default encoding/decoding roundtrip")
    func amqpBasicNackEncoding() async throws {
        let object = AMQP.Basic.Nack()
        try tester(object)
    }

}

@Suite struct Connection {
    @Test("AMQP.Connection.Start default encoding/decoding roundtrip")
    func amqpConnectionStartEncoding() async throws {
        let object = AMQP.Connection.Start(serverProperties: .init())
        try tester(object)
    }

    @Test("AMQP.Connection.StartOk default encoding/decoding roundtrip")
    func amqpConnectionStartOkEncoding() async throws {
        let object = AMQP.Connection.StartOk(clientProperties: .init(), response: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Connection.Secure default encoding/decoding roundtrip")
    func amqpConnectionSecureEncoding() async throws {
        let object = AMQP.Connection.Secure(challenge: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Connection.SecureOk default encoding/decoding roundtrip")
    func amqpConnectionSecureOkEncoding() async throws {
        let object = AMQP.Connection.SecureOk(response: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Connection.Tune default encoding/decoding roundtrip")
    func amqpConnectionTuneEncoding() async throws {
        let object = AMQP.Connection.Tune()
        try tester(object)
    }

    @Test("AMQP.Connection.TuneOk default encoding/decoding roundtrip")
    func amqpConnectionTuneOkEncoding() async throws {
        let object = AMQP.Connection.TuneOk()
        try tester(object)
    }

    @Test("AMQP.Connection.Open default encoding/decoding roundtrip")
    func amqpConnectionOpenEncoding() async throws {
        let object = AMQP.Connection.Open()
        try tester(object)
    }

    @Test("AMQP.Connection.OpenOk default encoding/decoding roundtrip")
    func amqpConnectionOpenOkEncoding() async throws {
        let object = AMQP.Connection.OpenOk()
        try tester(object)
    }

    @Test("AMQP.Connection.Close default encoding/decoding roundtrip")
    func amqpConnectionCloseEncoding() async throws {
        let object = AMQP.Connection.Close(replyCode: 1, classId: 1, methodId: 1)
        try tester(object)
    }

    @Test("AMQP.Connection.CloseOk default encoding/decoding roundtrip")
    func amqpConnectionCloseOkEncoding() async throws {
        let object = AMQP.Connection.CloseOk()
        try tester(object)
    }

    @Test("AMQP.Connection.Blocked default encoding/decoding roundtrip")
    func amqpConnectionBlockedEncoding() async throws {
        let object = AMQP.Connection.Blocked()
        try tester(object)
    }

    @Test("AMQP.Connection.Unblocked default encoding/decoding roundtrip")
    func amqpConnectionUnblockedEncoding() async throws {
        let object = AMQP.Connection.Unblocked()
        try tester(object)
    }

    @Test("AMQP.Connection.UpdateSecret default encoding/decoding roundtrip")
    func amqpConnectionUpdateSecretEncoding() async throws {
        let object = AMQP.Connection.UpdateSecret(newSecret: "FooBar", reason: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Connection.UpdateSecretOk default encoding/decoding roundtrip")
    func amqpConnectionUpdateSecretOkEncoding() async throws {
        let object = AMQP.Connection.UpdateSecretOk()
        try tester(object)
    }

}

@Suite struct Channel {
    @Test("AMQP.Channel.Open default encoding/decoding roundtrip")
    func amqpChannelOpenEncoding() async throws {
        let object = AMQP.Channel.Open()
        try tester(object)
    }

    @Test("AMQP.Channel.OpenOk default encoding/decoding roundtrip")
    func amqpChannelOpenOkEncoding() async throws {
        let object = AMQP.Channel.OpenOk()
        try tester(object)
    }

    @Test("AMQP.Channel.Flow default encoding/decoding roundtrip")
    func amqpChannelFlowEncoding() async throws {
        let object = AMQP.Channel.Flow(active: true)
        try tester(object)
    }

    @Test("AMQP.Channel.FlowOk default encoding/decoding roundtrip")
    func amqpChannelFlowOkEncoding() async throws {
        let object = AMQP.Channel.FlowOk(active: true)
        try tester(object)
    }

    @Test("AMQP.Channel.Close default encoding/decoding roundtrip")
    func amqpChannelCloseEncoding() async throws {
        let object = AMQP.Channel.Close(replyCode: 1, classId: 1, methodId: 1)
        try tester(object)
    }

    @Test("AMQP.Channel.CloseOk default encoding/decoding roundtrip")
    func amqpChannelCloseOkEncoding() async throws {
        let object = AMQP.Channel.CloseOk()
        try tester(object)
    }

}

@Suite struct Access {
    @Test("AMQP.Access.Request default encoding/decoding roundtrip")
    func amqpAccessRequestEncoding() async throws {
        let object = AMQP.Access.Request()
        try tester(object)
    }

    @Test("AMQP.Access.RequestOk default encoding/decoding roundtrip")
    func amqpAccessRequestOkEncoding() async throws {
        let object = AMQP.Access.RequestOk()
        try tester(object)
    }

}

@Suite struct Exchange {
    @Test("AMQP.Exchange.Declare default encoding/decoding roundtrip")
    func amqpExchangeDeclareEncoding() async throws {
        let object = AMQP.Exchange.Declare(exchange: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Exchange.DeclareOk default encoding/decoding roundtrip")
    func amqpExchangeDeclareOkEncoding() async throws {
        let object = AMQP.Exchange.DeclareOk()
        try tester(object)
    }

    @Test("AMQP.Exchange.Delete default encoding/decoding roundtrip")
    func amqpExchangeDeleteEncoding() async throws {
        let object = AMQP.Exchange.Delete(exchange: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Exchange.DeleteOk default encoding/decoding roundtrip")
    func amqpExchangeDeleteOkEncoding() async throws {
        let object = AMQP.Exchange.DeleteOk()
        try tester(object)
    }

    @Test("AMQP.Exchange.Bind default encoding/decoding roundtrip")
    func amqpExchangeBindEncoding() async throws {
        let object = AMQP.Exchange.Bind(destination: "FooBar", source: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Exchange.BindOk default encoding/decoding roundtrip")
    func amqpExchangeBindOkEncoding() async throws {
        let object = AMQP.Exchange.BindOk()
        try tester(object)
    }

    @Test("AMQP.Exchange.Unbind default encoding/decoding roundtrip")
    func amqpExchangeUnbindEncoding() async throws {
        let object = AMQP.Exchange.Unbind(destination: "FooBar", source: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Exchange.UnbindOk default encoding/decoding roundtrip")
    func amqpExchangeUnbindOkEncoding() async throws {
        let object = AMQP.Exchange.UnbindOk()
        try tester(object)
    }

}

@Suite struct Queue {
    @Test("AMQP.Queue.Declare default encoding/decoding roundtrip")
    func amqpQueueDeclareEncoding() async throws {
        let object = AMQP.Queue.Declare()
        try tester(object)
    }

    @Test("AMQP.Queue.DeclareOk default encoding/decoding roundtrip")
    func amqpQueueDeclareOkEncoding() async throws {
        let object = AMQP.Queue.DeclareOk(queue: "FooBar", messageCount: 1, consumerCount: 1)
        try tester(object)
    }

    @Test("AMQP.Queue.Bind default encoding/decoding roundtrip")
    func amqpQueueBindEncoding() async throws {
        let object = AMQP.Queue.Bind(exchange: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Queue.BindOk default encoding/decoding roundtrip")
    func amqpQueueBindOkEncoding() async throws {
        let object = AMQP.Queue.BindOk()
        try tester(object)
    }

    @Test("AMQP.Queue.Purge default encoding/decoding roundtrip")
    func amqpQueuePurgeEncoding() async throws {
        let object = AMQP.Queue.Purge()
        try tester(object)
    }

    @Test("AMQP.Queue.PurgeOk default encoding/decoding roundtrip")
    func amqpQueuePurgeOkEncoding() async throws {
        let object = AMQP.Queue.PurgeOk(messageCount: 1)
        try tester(object)
    }

    @Test("AMQP.Queue.Delete default encoding/decoding roundtrip")
    func amqpQueueDeleteEncoding() async throws {
        let object = AMQP.Queue.Delete()
        try tester(object)
    }

    @Test("AMQP.Queue.DeleteOk default encoding/decoding roundtrip")
    func amqpQueueDeleteOkEncoding() async throws {
        let object = AMQP.Queue.DeleteOk(messageCount: 1)
        try tester(object)
    }

    @Test("AMQP.Queue.Unbind default encoding/decoding roundtrip")
    func amqpQueueUnbindEncoding() async throws {
        let object = AMQP.Queue.Unbind(exchange: "FooBar")
        try tester(object)
    }

    @Test("AMQP.Queue.UnbindOk default encoding/decoding roundtrip")
    func amqpQueueUnbindOkEncoding() async throws {
        let object = AMQP.Queue.UnbindOk()
        try tester(object)
    }

}

@Suite struct Tx {
    @Test("AMQP.Tx.Select default encoding/decoding roundtrip")
    func amqpTxSelectEncoding() async throws {
        let object = AMQP.Tx.Select()
        try tester(object)
    }

    @Test("AMQP.Tx.SelectOk default encoding/decoding roundtrip")
    func amqpTxSelectOkEncoding() async throws {
        let object = AMQP.Tx.SelectOk()
        try tester(object)
    }

    @Test("AMQP.Tx.Commit default encoding/decoding roundtrip")
    func amqpTxCommitEncoding() async throws {
        let object = AMQP.Tx.Commit()
        try tester(object)
    }

    @Test("AMQP.Tx.CommitOk default encoding/decoding roundtrip")
    func amqpTxCommitOkEncoding() async throws {
        let object = AMQP.Tx.CommitOk()
        try tester(object)
    }

    @Test("AMQP.Tx.Rollback default encoding/decoding roundtrip")
    func amqpTxRollbackEncoding() async throws {
        let object = AMQP.Tx.Rollback()
        try tester(object)
    }

    @Test("AMQP.Tx.RollbackOk default encoding/decoding roundtrip")
    func amqpTxRollbackOkEncoding() async throws {
        let object = AMQP.Tx.RollbackOk()
        try tester(object)
    }

}

@Suite struct Confirm {
    @Test("AMQP.Confirm.Select default encoding/decoding roundtrip")
    func amqpConfirmSelectEncoding() async throws {
        let object = AMQP.Confirm.Select()
        try tester(object)
    }

    @Test("AMQP.Confirm.SelectOk default encoding/decoding roundtrip")
    func amqpConfirmSelectOkEncoding() async throws {
        let object = AMQP.Confirm.SelectOk()
        try tester(object)
    }

}

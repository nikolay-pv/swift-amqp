import Testing

@testable import AMQP

@Suite struct BasicDecode {
    @Test("AMQP.Basic.Qos verify decode bytes")
    func amqpBasicQosDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Qos")
        let decoded = try FrameDecoder().decode(AMQP.Basic.Qos.self, from: input)
        let expected = AMQP.Basic.Qos()
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.QosOk verify decode bytes")
    func amqpBasicQosOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.QosOk")
        let decoded = try FrameDecoder().decode(AMQP.Basic.QosOk.self, from: input)
        let expected = AMQP.Basic.QosOk()
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.Consume verify decode bytes")
    func amqpBasicConsumeDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Consume")
        let decoded = try FrameDecoder().decode(AMQP.Basic.Consume.self, from: input)
        let expected = AMQP.Basic.Consume()
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.ConsumeOk verify decode bytes")
    func amqpBasicConsumeOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.ConsumeOk")
        let decoded = try FrameDecoder().decode(AMQP.Basic.ConsumeOk.self, from: input)
        let expected = AMQP.Basic.ConsumeOk(consumerTag: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.Cancel verify decode bytes")
    func amqpBasicCancelDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Cancel")
        let decoded = try FrameDecoder().decode(AMQP.Basic.Cancel.self, from: input)
        let expected = AMQP.Basic.Cancel(consumerTag: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.CancelOk verify decode bytes")
    func amqpBasicCancelOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.CancelOk")
        let decoded = try FrameDecoder().decode(AMQP.Basic.CancelOk.self, from: input)
        let expected = AMQP.Basic.CancelOk(consumerTag: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.Publish verify decode bytes")
    func amqpBasicPublishDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Publish")
        let decoded = try FrameDecoder().decode(AMQP.Basic.Publish.self, from: input)
        let expected = AMQP.Basic.Publish()
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.Return verify decode bytes")
    func amqpBasicReturnDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Return")
        let decoded = try FrameDecoder().decode(AMQP.Basic.Return.self, from: input)
        let expected = AMQP.Basic.Return(replyCode: 1, exchange: "FooBar", routingKey: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.Deliver verify decode bytes")
    func amqpBasicDeliverDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Deliver")
        let decoded = try FrameDecoder().decode(AMQP.Basic.Deliver.self, from: input)
        let expected = AMQP.Basic.Deliver(consumerTag: "FooBar", deliveryTag: 1, exchange: "FooBar", routingKey: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.Get verify decode bytes")
    func amqpBasicGetDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Get")
        let decoded = try FrameDecoder().decode(AMQP.Basic.Get.self, from: input)
        let expected = AMQP.Basic.Get()
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.GetOk verify decode bytes")
    func amqpBasicGetOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.GetOk")
        let decoded = try FrameDecoder().decode(AMQP.Basic.GetOk.self, from: input)
        let expected = AMQP.Basic.GetOk(deliveryTag: 1, exchange: "FooBar", routingKey: "FooBar", messageCount: 1)
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.GetEmpty verify decode bytes")
    func amqpBasicGetEmptyDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.GetEmpty")
        let decoded = try FrameDecoder().decode(AMQP.Basic.GetEmpty.self, from: input)
        let expected = AMQP.Basic.GetEmpty()
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.Ack verify decode bytes")
    func amqpBasicAckDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Ack")
        let decoded = try FrameDecoder().decode(AMQP.Basic.Ack.self, from: input)
        let expected = AMQP.Basic.Ack()
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.Reject verify decode bytes")
    func amqpBasicRejectDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Reject")
        let decoded = try FrameDecoder().decode(AMQP.Basic.Reject.self, from: input)
        let expected = AMQP.Basic.Reject(deliveryTag: 1)
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.RecoverAsync verify decode bytes")
    func amqpBasicRecoverAsyncDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.RecoverAsync")
        let decoded = try FrameDecoder().decode(AMQP.Basic.RecoverAsync.self, from: input)
        let expected = AMQP.Basic.RecoverAsync()
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.Recover verify decode bytes")
    func amqpBasicRecoverDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Recover")
        let decoded = try FrameDecoder().decode(AMQP.Basic.Recover.self, from: input)
        let expected = AMQP.Basic.Recover()
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.RecoverOk verify decode bytes")
    func amqpBasicRecoverOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.RecoverOk")
        let decoded = try FrameDecoder().decode(AMQP.Basic.RecoverOk.self, from: input)
        let expected = AMQP.Basic.RecoverOk()
        #expect(decoded == expected)
    }

    @Test("AMQP.Basic.Nack verify decode bytes")
    func amqpBasicNackDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Nack")
        let decoded = try FrameDecoder().decode(AMQP.Basic.Nack.self, from: input)
        let expected = AMQP.Basic.Nack()
        #expect(decoded == expected)
    }

}

@Suite struct ConnectionDecode {
    @Test("AMQP.Connection.Start verify decode bytes")
    func amqpConnectionStartDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.Start")
        let decoded = try FrameDecoder().decode(AMQP.Connection.Start.self, from: input)
        let expected = AMQP.Connection.Start(serverProperties: .init())
        #expect(decoded == expected)
    }

    @Test("AMQP.Connection.StartOk verify decode bytes")
    func amqpConnectionStartOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.StartOk")
        let decoded = try FrameDecoder().decode(AMQP.Connection.StartOk.self, from: input)
        let expected = AMQP.Connection.StartOk(clientProperties: .init(), response: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Connection.Secure verify decode bytes")
    func amqpConnectionSecureDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.Secure")
        let decoded = try FrameDecoder().decode(AMQP.Connection.Secure.self, from: input)
        let expected = AMQP.Connection.Secure(challenge: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Connection.SecureOk verify decode bytes")
    func amqpConnectionSecureOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.SecureOk")
        let decoded = try FrameDecoder().decode(AMQP.Connection.SecureOk.self, from: input)
        let expected = AMQP.Connection.SecureOk(response: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Connection.Tune verify decode bytes")
    func amqpConnectionTuneDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.Tune")
        let decoded = try FrameDecoder().decode(AMQP.Connection.Tune.self, from: input)
        let expected = AMQP.Connection.Tune()
        #expect(decoded == expected)
    }

    @Test("AMQP.Connection.TuneOk verify decode bytes")
    func amqpConnectionTuneOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.TuneOk")
        let decoded = try FrameDecoder().decode(AMQP.Connection.TuneOk.self, from: input)
        let expected = AMQP.Connection.TuneOk()
        #expect(decoded == expected)
    }

    @Test("AMQP.Connection.Open verify decode bytes")
    func amqpConnectionOpenDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.Open")
        let decoded = try FrameDecoder().decode(AMQP.Connection.Open.self, from: input)
        let expected = AMQP.Connection.Open()
        #expect(decoded == expected)
    }

    @Test("AMQP.Connection.OpenOk verify decode bytes")
    func amqpConnectionOpenOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.OpenOk")
        let decoded = try FrameDecoder().decode(AMQP.Connection.OpenOk.self, from: input)
        let expected = AMQP.Connection.OpenOk()
        #expect(decoded == expected)
    }

    @Test("AMQP.Connection.Close verify decode bytes")
    func amqpConnectionCloseDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.Close")
        let decoded = try FrameDecoder().decode(AMQP.Connection.Close.self, from: input)
        let expected = AMQP.Connection.Close(replyCode: 1, classId: 1, methodId: 1)
        #expect(decoded == expected)
    }

    @Test("AMQP.Connection.CloseOk verify decode bytes")
    func amqpConnectionCloseOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.CloseOk")
        let decoded = try FrameDecoder().decode(AMQP.Connection.CloseOk.self, from: input)
        let expected = AMQP.Connection.CloseOk()
        #expect(decoded == expected)
    }

    @Test("AMQP.Connection.Blocked verify decode bytes")
    func amqpConnectionBlockedDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.Blocked")
        let decoded = try FrameDecoder().decode(AMQP.Connection.Blocked.self, from: input)
        let expected = AMQP.Connection.Blocked()
        #expect(decoded == expected)
    }

    @Test("AMQP.Connection.Unblocked verify decode bytes")
    func amqpConnectionUnblockedDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.Unblocked")
        let decoded = try FrameDecoder().decode(AMQP.Connection.Unblocked.self, from: input)
        let expected = AMQP.Connection.Unblocked()
        #expect(decoded == expected)
    }

    @Test("AMQP.Connection.UpdateSecret verify decode bytes")
    func amqpConnectionUpdateSecretDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.UpdateSecret")
        let decoded = try FrameDecoder().decode(AMQP.Connection.UpdateSecret.self, from: input)
        let expected = AMQP.Connection.UpdateSecret(newSecret: "FooBar", reason: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Connection.UpdateSecretOk verify decode bytes")
    func amqpConnectionUpdateSecretOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.UpdateSecretOk")
        let decoded = try FrameDecoder().decode(AMQP.Connection.UpdateSecretOk.self, from: input)
        let expected = AMQP.Connection.UpdateSecretOk()
        #expect(decoded == expected)
    }

}

@Suite struct ChannelDecode {
    @Test("AMQP.Channel.Open verify decode bytes")
    func amqpChannelOpenDecodeBytes() async throws {
        let input = try fixtureData(for: "Channel.Open")
        let decoded = try FrameDecoder().decode(AMQP.Channel.Open.self, from: input)
        let expected = AMQP.Channel.Open()
        #expect(decoded == expected)
    }

    @Test("AMQP.Channel.OpenOk verify decode bytes")
    func amqpChannelOpenOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Channel.OpenOk")
        let decoded = try FrameDecoder().decode(AMQP.Channel.OpenOk.self, from: input)
        let expected = AMQP.Channel.OpenOk()
        #expect(decoded == expected)
    }

    @Test("AMQP.Channel.Flow verify decode bytes")
    func amqpChannelFlowDecodeBytes() async throws {
        let input = try fixtureData(for: "Channel.Flow")
        let decoded = try FrameDecoder().decode(AMQP.Channel.Flow.self, from: input)
        let expected = AMQP.Channel.Flow(active: true)
        #expect(decoded == expected)
    }

    @Test("AMQP.Channel.FlowOk verify decode bytes")
    func amqpChannelFlowOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Channel.FlowOk")
        let decoded = try FrameDecoder().decode(AMQP.Channel.FlowOk.self, from: input)
        let expected = AMQP.Channel.FlowOk(active: true)
        #expect(decoded == expected)
    }

    @Test("AMQP.Channel.Close verify decode bytes")
    func amqpChannelCloseDecodeBytes() async throws {
        let input = try fixtureData(for: "Channel.Close")
        let decoded = try FrameDecoder().decode(AMQP.Channel.Close.self, from: input)
        let expected = AMQP.Channel.Close(replyCode: 1, classId: 1, methodId: 1)
        #expect(decoded == expected)
    }

    @Test("AMQP.Channel.CloseOk verify decode bytes")
    func amqpChannelCloseOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Channel.CloseOk")
        let decoded = try FrameDecoder().decode(AMQP.Channel.CloseOk.self, from: input)
        let expected = AMQP.Channel.CloseOk()
        #expect(decoded == expected)
    }

}

@Suite struct AccessDecode {
    @Test("AMQP.Access.Request verify decode bytes")
    func amqpAccessRequestDecodeBytes() async throws {
        let input = try fixtureData(for: "Access.Request")
        let decoded = try FrameDecoder().decode(AMQP.Access.Request.self, from: input)
        let expected = AMQP.Access.Request()
        #expect(decoded == expected)
    }

    @Test("AMQP.Access.RequestOk verify decode bytes")
    func amqpAccessRequestOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Access.RequestOk")
        let decoded = try FrameDecoder().decode(AMQP.Access.RequestOk.self, from: input)
        let expected = AMQP.Access.RequestOk()
        #expect(decoded == expected)
    }

}

@Suite struct ExchangeDecode {
    @Test("AMQP.Exchange.Declare verify decode bytes")
    func amqpExchangeDeclareDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.Declare")
        let decoded = try FrameDecoder().decode(AMQP.Exchange.Declare.self, from: input)
        let expected = AMQP.Exchange.Declare(exchange: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Exchange.DeclareOk verify decode bytes")
    func amqpExchangeDeclareOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.DeclareOk")
        let decoded = try FrameDecoder().decode(AMQP.Exchange.DeclareOk.self, from: input)
        let expected = AMQP.Exchange.DeclareOk()
        #expect(decoded == expected)
    }

    @Test("AMQP.Exchange.Delete verify decode bytes")
    func amqpExchangeDeleteDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.Delete")
        let decoded = try FrameDecoder().decode(AMQP.Exchange.Delete.self, from: input)
        let expected = AMQP.Exchange.Delete(exchange: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Exchange.DeleteOk verify decode bytes")
    func amqpExchangeDeleteOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.DeleteOk")
        let decoded = try FrameDecoder().decode(AMQP.Exchange.DeleteOk.self, from: input)
        let expected = AMQP.Exchange.DeleteOk()
        #expect(decoded == expected)
    }

    @Test("AMQP.Exchange.Bind verify decode bytes")
    func amqpExchangeBindDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.Bind")
        let decoded = try FrameDecoder().decode(AMQP.Exchange.Bind.self, from: input)
        let expected = AMQP.Exchange.Bind(destination: "FooBar", source: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Exchange.BindOk verify decode bytes")
    func amqpExchangeBindOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.BindOk")
        let decoded = try FrameDecoder().decode(AMQP.Exchange.BindOk.self, from: input)
        let expected = AMQP.Exchange.BindOk()
        #expect(decoded == expected)
    }

    @Test("AMQP.Exchange.Unbind verify decode bytes")
    func amqpExchangeUnbindDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.Unbind")
        let decoded = try FrameDecoder().decode(AMQP.Exchange.Unbind.self, from: input)
        let expected = AMQP.Exchange.Unbind(destination: "FooBar", source: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Exchange.UnbindOk verify decode bytes")
    func amqpExchangeUnbindOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.UnbindOk")
        let decoded = try FrameDecoder().decode(AMQP.Exchange.UnbindOk.self, from: input)
        let expected = AMQP.Exchange.UnbindOk()
        #expect(decoded == expected)
    }

}

@Suite struct QueueDecode {
    @Test("AMQP.Queue.Declare verify decode bytes")
    func amqpQueueDeclareDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.Declare")
        let decoded = try FrameDecoder().decode(AMQP.Queue.Declare.self, from: input)
        let expected = AMQP.Queue.Declare()
        #expect(decoded == expected)
    }

    @Test("AMQP.Queue.DeclareOk verify decode bytes")
    func amqpQueueDeclareOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.DeclareOk")
        let decoded = try FrameDecoder().decode(AMQP.Queue.DeclareOk.self, from: input)
        let expected = AMQP.Queue.DeclareOk(queue: "FooBar", messageCount: 1, consumerCount: 1)
        #expect(decoded == expected)
    }

    @Test("AMQP.Queue.Bind verify decode bytes")
    func amqpQueueBindDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.Bind")
        let decoded = try FrameDecoder().decode(AMQP.Queue.Bind.self, from: input)
        let expected = AMQP.Queue.Bind(exchange: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Queue.BindOk verify decode bytes")
    func amqpQueueBindOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.BindOk")
        let decoded = try FrameDecoder().decode(AMQP.Queue.BindOk.self, from: input)
        let expected = AMQP.Queue.BindOk()
        #expect(decoded == expected)
    }

    @Test("AMQP.Queue.Purge verify decode bytes")
    func amqpQueuePurgeDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.Purge")
        let decoded = try FrameDecoder().decode(AMQP.Queue.Purge.self, from: input)
        let expected = AMQP.Queue.Purge()
        #expect(decoded == expected)
    }

    @Test("AMQP.Queue.PurgeOk verify decode bytes")
    func amqpQueuePurgeOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.PurgeOk")
        let decoded = try FrameDecoder().decode(AMQP.Queue.PurgeOk.self, from: input)
        let expected = AMQP.Queue.PurgeOk(messageCount: 1)
        #expect(decoded == expected)
    }

    @Test("AMQP.Queue.Delete verify decode bytes")
    func amqpQueueDeleteDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.Delete")
        let decoded = try FrameDecoder().decode(AMQP.Queue.Delete.self, from: input)
        let expected = AMQP.Queue.Delete()
        #expect(decoded == expected)
    }

    @Test("AMQP.Queue.DeleteOk verify decode bytes")
    func amqpQueueDeleteOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.DeleteOk")
        let decoded = try FrameDecoder().decode(AMQP.Queue.DeleteOk.self, from: input)
        let expected = AMQP.Queue.DeleteOk(messageCount: 1)
        #expect(decoded == expected)
    }

    @Test("AMQP.Queue.Unbind verify decode bytes")
    func amqpQueueUnbindDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.Unbind")
        let decoded = try FrameDecoder().decode(AMQP.Queue.Unbind.self, from: input)
        let expected = AMQP.Queue.Unbind(exchange: "FooBar")
        #expect(decoded == expected)
    }

    @Test("AMQP.Queue.UnbindOk verify decode bytes")
    func amqpQueueUnbindOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.UnbindOk")
        let decoded = try FrameDecoder().decode(AMQP.Queue.UnbindOk.self, from: input)
        let expected = AMQP.Queue.UnbindOk()
        #expect(decoded == expected)
    }

}

@Suite struct TxDecode {
    @Test("AMQP.Tx.Select verify decode bytes")
    func amqpTxSelectDecodeBytes() async throws {
        let input = try fixtureData(for: "Tx.Select")
        let decoded = try FrameDecoder().decode(AMQP.Tx.Select.self, from: input)
        let expected = AMQP.Tx.Select()
        #expect(decoded == expected)
    }

    @Test("AMQP.Tx.SelectOk verify decode bytes")
    func amqpTxSelectOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Tx.SelectOk")
        let decoded = try FrameDecoder().decode(AMQP.Tx.SelectOk.self, from: input)
        let expected = AMQP.Tx.SelectOk()
        #expect(decoded == expected)
    }

    @Test("AMQP.Tx.Commit verify decode bytes")
    func amqpTxCommitDecodeBytes() async throws {
        let input = try fixtureData(for: "Tx.Commit")
        let decoded = try FrameDecoder().decode(AMQP.Tx.Commit.self, from: input)
        let expected = AMQP.Tx.Commit()
        #expect(decoded == expected)
    }

    @Test("AMQP.Tx.CommitOk verify decode bytes")
    func amqpTxCommitOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Tx.CommitOk")
        let decoded = try FrameDecoder().decode(AMQP.Tx.CommitOk.self, from: input)
        let expected = AMQP.Tx.CommitOk()
        #expect(decoded == expected)
    }

    @Test("AMQP.Tx.Rollback verify decode bytes")
    func amqpTxRollbackDecodeBytes() async throws {
        let input = try fixtureData(for: "Tx.Rollback")
        let decoded = try FrameDecoder().decode(AMQP.Tx.Rollback.self, from: input)
        let expected = AMQP.Tx.Rollback()
        #expect(decoded == expected)
    }

    @Test("AMQP.Tx.RollbackOk verify decode bytes")
    func amqpTxRollbackOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Tx.RollbackOk")
        let decoded = try FrameDecoder().decode(AMQP.Tx.RollbackOk.self, from: input)
        let expected = AMQP.Tx.RollbackOk()
        #expect(decoded == expected)
    }

}

@Suite struct ConfirmDecode {
    @Test("AMQP.Confirm.Select verify decode bytes")
    func amqpConfirmSelectDecodeBytes() async throws {
        let input = try fixtureData(for: "Confirm.Select")
        let decoded = try FrameDecoder().decode(AMQP.Confirm.Select.self, from: input)
        let expected = AMQP.Confirm.Select()
        #expect(decoded == expected)
    }

    @Test("AMQP.Confirm.SelectOk verify decode bytes")
    func amqpConfirmSelectOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Confirm.SelectOk")
        let decoded = try FrameDecoder().decode(AMQP.Confirm.SelectOk.self, from: input)
        let expected = AMQP.Confirm.SelectOk()
        #expect(decoded == expected)
    }

}

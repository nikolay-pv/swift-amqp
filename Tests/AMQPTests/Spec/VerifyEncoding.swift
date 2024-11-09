import Testing

@testable import AMQP

@Suite struct BasicDecode {
    @Test("Spec.Basic.Qos verify decode bytes")
    func amqpBasicQosDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Qos")
        let decoded = try FrameDecoder().decode(Spec.Basic.Qos.self, from: input)
        let expected = Spec.Basic.Qos()
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.QosOk verify decode bytes")
    func amqpBasicQosOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.QosOk")
        let decoded = try FrameDecoder().decode(Spec.Basic.QosOk.self, from: input)
        let expected = Spec.Basic.QosOk()
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.Consume verify decode bytes")
    func amqpBasicConsumeDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Consume")
        let decoded = try FrameDecoder().decode(Spec.Basic.Consume.self, from: input)
        let expected = Spec.Basic.Consume()
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.ConsumeOk verify decode bytes")
    func amqpBasicConsumeOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.ConsumeOk")
        let decoded = try FrameDecoder().decode(Spec.Basic.ConsumeOk.self, from: input)
        let expected = Spec.Basic.ConsumeOk(consumerTag: "FooBar")
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.Cancel verify decode bytes")
    func amqpBasicCancelDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Cancel")
        let decoded = try FrameDecoder().decode(Spec.Basic.Cancel.self, from: input)
        let expected = Spec.Basic.Cancel(consumerTag: "FooBar")
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.CancelOk verify decode bytes")
    func amqpBasicCancelOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.CancelOk")
        let decoded = try FrameDecoder().decode(Spec.Basic.CancelOk.self, from: input)
        let expected = Spec.Basic.CancelOk(consumerTag: "FooBar")
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.Publish verify decode bytes")
    func amqpBasicPublishDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Publish")
        let decoded = try FrameDecoder().decode(Spec.Basic.Publish.self, from: input)
        let expected = Spec.Basic.Publish()
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.Return verify decode bytes")
    func amqpBasicReturnDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Return")
        let decoded = try FrameDecoder().decode(Spec.Basic.Return.self, from: input)
        let expected = Spec.Basic.Return(replyCode: 1, exchange: "FooBar", routingKey: "FooBar")
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.Deliver verify decode bytes")
    func amqpBasicDeliverDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Deliver")
        let decoded = try FrameDecoder().decode(Spec.Basic.Deliver.self, from: input)
        let expected = Spec.Basic.Deliver(
            consumerTag: "FooBar",
            deliveryTag: 1,
            exchange: "FooBar",
            routingKey: "FooBar"
        )
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.Get verify decode bytes")
    func amqpBasicGetDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Get")
        let decoded = try FrameDecoder().decode(Spec.Basic.Get.self, from: input)
        let expected = Spec.Basic.Get()
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.GetOk verify decode bytes")
    func amqpBasicGetOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.GetOk")
        let decoded = try FrameDecoder().decode(Spec.Basic.GetOk.self, from: input)
        let expected = Spec.Basic.GetOk(
            deliveryTag: 1,
            exchange: "FooBar",
            routingKey: "FooBar",
            messageCount: 1
        )
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.GetEmpty verify decode bytes")
    func amqpBasicGetEmptyDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.GetEmpty")
        let decoded = try FrameDecoder().decode(Spec.Basic.GetEmpty.self, from: input)
        let expected = Spec.Basic.GetEmpty()
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.Ack verify decode bytes")
    func amqpBasicAckDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Ack")
        let decoded = try FrameDecoder().decode(Spec.Basic.Ack.self, from: input)
        let expected = Spec.Basic.Ack()
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.Reject verify decode bytes")
    func amqpBasicRejectDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Reject")
        let decoded = try FrameDecoder().decode(Spec.Basic.Reject.self, from: input)
        let expected = Spec.Basic.Reject(deliveryTag: 1)
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.RecoverAsync verify decode bytes")
    func amqpBasicRecoverAsyncDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.RecoverAsync")
        let decoded = try FrameDecoder().decode(Spec.Basic.RecoverAsync.self, from: input)
        let expected = Spec.Basic.RecoverAsync()
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.Recover verify decode bytes")
    func amqpBasicRecoverDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Recover")
        let decoded = try FrameDecoder().decode(Spec.Basic.Recover.self, from: input)
        let expected = Spec.Basic.Recover()
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.RecoverOk verify decode bytes")
    func amqpBasicRecoverOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.RecoverOk")
        let decoded = try FrameDecoder().decode(Spec.Basic.RecoverOk.self, from: input)
        let expected = Spec.Basic.RecoverOk()
        #expect(decoded == expected)
    }

    @Test("Spec.Basic.Nack verify decode bytes")
    func amqpBasicNackDecodeBytes() async throws {
        let input = try fixtureData(for: "Basic.Nack")
        let decoded = try FrameDecoder().decode(Spec.Basic.Nack.self, from: input)
        let expected = Spec.Basic.Nack()
        #expect(decoded == expected)
    }

}

@Suite struct ConnectionDecode {
    @Test("Spec.Connection.Start verify decode bytes")
    func amqpConnectionStartDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.Start")
        let decoded = try FrameDecoder().decode(Spec.Connection.Start.self, from: input)
        let expected = Spec.Connection.Start(serverProperties: .init())
        #expect(decoded == expected)
    }

    @Test("Spec.Connection.StartOk verify decode bytes")
    func amqpConnectionStartOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.StartOk")
        let decoded = try FrameDecoder().decode(Spec.Connection.StartOk.self, from: input)
        let expected = Spec.Connection.StartOk(clientProperties: .init(), response: "FooBar")
        #expect(decoded == expected)
    }

    @Test("Spec.Connection.Secure verify decode bytes")
    func amqpConnectionSecureDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.Secure")
        let decoded = try FrameDecoder().decode(Spec.Connection.Secure.self, from: input)
        let expected = Spec.Connection.Secure(challenge: "FooBar")
        #expect(decoded == expected)
    }

    @Test("Spec.Connection.SecureOk verify decode bytes")
    func amqpConnectionSecureOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.SecureOk")
        let decoded = try FrameDecoder().decode(Spec.Connection.SecureOk.self, from: input)
        let expected = Spec.Connection.SecureOk(response: "FooBar")
        #expect(decoded == expected)
    }

    @Test("Spec.Connection.Tune verify decode bytes")
    func amqpConnectionTuneDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.Tune")
        let decoded = try FrameDecoder().decode(Spec.Connection.Tune.self, from: input)
        let expected = Spec.Connection.Tune()
        #expect(decoded == expected)
    }

    @Test("Spec.Connection.TuneOk verify decode bytes")
    func amqpConnectionTuneOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.TuneOk")
        let decoded = try FrameDecoder().decode(Spec.Connection.TuneOk.self, from: input)
        let expected = Spec.Connection.TuneOk()
        #expect(decoded == expected)
    }

    @Test("Spec.Connection.Open verify decode bytes")
    func amqpConnectionOpenDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.Open")
        let decoded = try FrameDecoder().decode(Spec.Connection.Open.self, from: input)
        let expected = Spec.Connection.Open()
        #expect(decoded == expected)
    }

    @Test("Spec.Connection.OpenOk verify decode bytes")
    func amqpConnectionOpenOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.OpenOk")
        let decoded = try FrameDecoder().decode(Spec.Connection.OpenOk.self, from: input)
        let expected = Spec.Connection.OpenOk()
        #expect(decoded == expected)
    }

    @Test("Spec.Connection.Close verify decode bytes")
    func amqpConnectionCloseDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.Close")
        let decoded = try FrameDecoder().decode(Spec.Connection.Close.self, from: input)
        let expected = Spec.Connection.Close(replyCode: 1, classId: 1, methodId: 1)
        #expect(decoded == expected)
    }

    @Test("Spec.Connection.CloseOk verify decode bytes")
    func amqpConnectionCloseOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.CloseOk")
        let decoded = try FrameDecoder().decode(Spec.Connection.CloseOk.self, from: input)
        let expected = Spec.Connection.CloseOk()
        #expect(decoded == expected)
    }

    @Test("Spec.Connection.Blocked verify decode bytes")
    func amqpConnectionBlockedDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.Blocked")
        let decoded = try FrameDecoder().decode(Spec.Connection.Blocked.self, from: input)
        let expected = Spec.Connection.Blocked()
        #expect(decoded == expected)
    }

    @Test("Spec.Connection.Unblocked verify decode bytes")
    func amqpConnectionUnblockedDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.Unblocked")
        let decoded = try FrameDecoder().decode(Spec.Connection.Unblocked.self, from: input)
        let expected = Spec.Connection.Unblocked()
        #expect(decoded == expected)
    }

    @Test("Spec.Connection.UpdateSecret verify decode bytes")
    func amqpConnectionUpdateSecretDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.UpdateSecret")
        let decoded = try FrameDecoder().decode(Spec.Connection.UpdateSecret.self, from: input)
        let expected = Spec.Connection.UpdateSecret(newSecret: "FooBar", reason: "FooBar")
        #expect(decoded == expected)
    }

    @Test("Spec.Connection.UpdateSecretOk verify decode bytes")
    func amqpConnectionUpdateSecretOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Connection.UpdateSecretOk")
        let decoded = try FrameDecoder().decode(Spec.Connection.UpdateSecretOk.self, from: input)
        let expected = Spec.Connection.UpdateSecretOk()
        #expect(decoded == expected)
    }

}

@Suite struct ChannelDecode {
    @Test("Spec.Channel.Open verify decode bytes")
    func amqpChannelOpenDecodeBytes() async throws {
        let input = try fixtureData(for: "Channel.Open")
        let decoded = try FrameDecoder().decode(Spec.Channel.Open.self, from: input)
        let expected = Spec.Channel.Open()
        #expect(decoded == expected)
    }

    @Test("Spec.Channel.OpenOk verify decode bytes")
    func amqpChannelOpenOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Channel.OpenOk")
        let decoded = try FrameDecoder().decode(Spec.Channel.OpenOk.self, from: input)
        let expected = Spec.Channel.OpenOk()
        #expect(decoded == expected)
    }

    @Test("Spec.Channel.Flow verify decode bytes")
    func amqpChannelFlowDecodeBytes() async throws {
        let input = try fixtureData(for: "Channel.Flow")
        let decoded = try FrameDecoder().decode(Spec.Channel.Flow.self, from: input)
        let expected = Spec.Channel.Flow(active: true)
        #expect(decoded == expected)
    }

    @Test("Spec.Channel.FlowOk verify decode bytes")
    func amqpChannelFlowOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Channel.FlowOk")
        let decoded = try FrameDecoder().decode(Spec.Channel.FlowOk.self, from: input)
        let expected = Spec.Channel.FlowOk(active: true)
        #expect(decoded == expected)
    }

    @Test("Spec.Channel.Close verify decode bytes")
    func amqpChannelCloseDecodeBytes() async throws {
        let input = try fixtureData(for: "Channel.Close")
        let decoded = try FrameDecoder().decode(Spec.Channel.Close.self, from: input)
        let expected = Spec.Channel.Close(replyCode: 1, classId: 1, methodId: 1)
        #expect(decoded == expected)
    }

    @Test("Spec.Channel.CloseOk verify decode bytes")
    func amqpChannelCloseOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Channel.CloseOk")
        let decoded = try FrameDecoder().decode(Spec.Channel.CloseOk.self, from: input)
        let expected = Spec.Channel.CloseOk()
        #expect(decoded == expected)
    }

}

@Suite struct AccessDecode {
    @Test("Spec.Access.Request verify decode bytes")
    func amqpAccessRequestDecodeBytes() async throws {
        let input = try fixtureData(for: "Access.Request")
        let decoded = try FrameDecoder().decode(Spec.Access.Request.self, from: input)
        let expected = Spec.Access.Request()
        #expect(decoded == expected)
    }

    @Test("Spec.Access.RequestOk verify decode bytes")
    func amqpAccessRequestOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Access.RequestOk")
        let decoded = try FrameDecoder().decode(Spec.Access.RequestOk.self, from: input)
        let expected = Spec.Access.RequestOk()
        #expect(decoded == expected)
    }

}

@Suite struct ExchangeDecode {
    @Test("Spec.Exchange.Declare verify decode bytes")
    func amqpExchangeDeclareDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.Declare")
        let decoded = try FrameDecoder().decode(Spec.Exchange.Declare.self, from: input)
        let expected = Spec.Exchange.Declare(exchange: "FooBar")
        #expect(decoded == expected)
    }

    @Test("Spec.Exchange.DeclareOk verify decode bytes")
    func amqpExchangeDeclareOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.DeclareOk")
        let decoded = try FrameDecoder().decode(Spec.Exchange.DeclareOk.self, from: input)
        let expected = Spec.Exchange.DeclareOk()
        #expect(decoded == expected)
    }

    @Test("Spec.Exchange.Delete verify decode bytes")
    func amqpExchangeDeleteDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.Delete")
        let decoded = try FrameDecoder().decode(Spec.Exchange.Delete.self, from: input)
        let expected = Spec.Exchange.Delete(exchange: "FooBar")
        #expect(decoded == expected)
    }

    @Test("Spec.Exchange.DeleteOk verify decode bytes")
    func amqpExchangeDeleteOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.DeleteOk")
        let decoded = try FrameDecoder().decode(Spec.Exchange.DeleteOk.self, from: input)
        let expected = Spec.Exchange.DeleteOk()
        #expect(decoded == expected)
    }

    @Test("Spec.Exchange.Bind verify decode bytes")
    func amqpExchangeBindDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.Bind")
        let decoded = try FrameDecoder().decode(Spec.Exchange.Bind.self, from: input)
        let expected = Spec.Exchange.Bind(destination: "FooBar", source: "FooBar")
        #expect(decoded == expected)
    }

    @Test("Spec.Exchange.BindOk verify decode bytes")
    func amqpExchangeBindOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.BindOk")
        let decoded = try FrameDecoder().decode(Spec.Exchange.BindOk.self, from: input)
        let expected = Spec.Exchange.BindOk()
        #expect(decoded == expected)
    }

    @Test("Spec.Exchange.Unbind verify decode bytes")
    func amqpExchangeUnbindDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.Unbind")
        let decoded = try FrameDecoder().decode(Spec.Exchange.Unbind.self, from: input)
        let expected = Spec.Exchange.Unbind(destination: "FooBar", source: "FooBar")
        #expect(decoded == expected)
    }

    @Test("Spec.Exchange.UnbindOk verify decode bytes")
    func amqpExchangeUnbindOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Exchange.UnbindOk")
        let decoded = try FrameDecoder().decode(Spec.Exchange.UnbindOk.self, from: input)
        let expected = Spec.Exchange.UnbindOk()
        #expect(decoded == expected)
    }

}

@Suite struct QueueDecode {
    @Test("Spec.Queue.Declare verify decode bytes")
    func amqpQueueDeclareDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.Declare")
        let decoded = try FrameDecoder().decode(Spec.Queue.Declare.self, from: input)
        let expected = Spec.Queue.Declare()
        #expect(decoded == expected)
    }

    @Test("Spec.Queue.DeclareOk verify decode bytes")
    func amqpQueueDeclareOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.DeclareOk")
        let decoded = try FrameDecoder().decode(Spec.Queue.DeclareOk.self, from: input)
        let expected = Spec.Queue.DeclareOk(queue: "FooBar", messageCount: 1, consumerCount: 1)
        #expect(decoded == expected)
    }

    @Test("Spec.Queue.Bind verify decode bytes")
    func amqpQueueBindDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.Bind")
        let decoded = try FrameDecoder().decode(Spec.Queue.Bind.self, from: input)
        let expected = Spec.Queue.Bind(exchange: "FooBar")
        #expect(decoded == expected)
    }

    @Test("Spec.Queue.BindOk verify decode bytes")
    func amqpQueueBindOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.BindOk")
        let decoded = try FrameDecoder().decode(Spec.Queue.BindOk.self, from: input)
        let expected = Spec.Queue.BindOk()
        #expect(decoded == expected)
    }

    @Test("Spec.Queue.Purge verify decode bytes")
    func amqpQueuePurgeDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.Purge")
        let decoded = try FrameDecoder().decode(Spec.Queue.Purge.self, from: input)
        let expected = Spec.Queue.Purge()
        #expect(decoded == expected)
    }

    @Test("Spec.Queue.PurgeOk verify decode bytes")
    func amqpQueuePurgeOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.PurgeOk")
        let decoded = try FrameDecoder().decode(Spec.Queue.PurgeOk.self, from: input)
        let expected = Spec.Queue.PurgeOk(messageCount: 1)
        #expect(decoded == expected)
    }

    @Test("Spec.Queue.Delete verify decode bytes")
    func amqpQueueDeleteDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.Delete")
        let decoded = try FrameDecoder().decode(Spec.Queue.Delete.self, from: input)
        let expected = Spec.Queue.Delete()
        #expect(decoded == expected)
    }

    @Test("Spec.Queue.DeleteOk verify decode bytes")
    func amqpQueueDeleteOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.DeleteOk")
        let decoded = try FrameDecoder().decode(Spec.Queue.DeleteOk.self, from: input)
        let expected = Spec.Queue.DeleteOk(messageCount: 1)
        #expect(decoded == expected)
    }

    @Test("Spec.Queue.Unbind verify decode bytes")
    func amqpQueueUnbindDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.Unbind")
        let decoded = try FrameDecoder().decode(Spec.Queue.Unbind.self, from: input)
        let expected = Spec.Queue.Unbind(exchange: "FooBar")
        #expect(decoded == expected)
    }

    @Test("Spec.Queue.UnbindOk verify decode bytes")
    func amqpQueueUnbindOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Queue.UnbindOk")
        let decoded = try FrameDecoder().decode(Spec.Queue.UnbindOk.self, from: input)
        let expected = Spec.Queue.UnbindOk()
        #expect(decoded == expected)
    }

}

@Suite struct TxDecode {
    @Test("Spec.Tx.Select verify decode bytes")
    func amqpTxSelectDecodeBytes() async throws {
        let input = try fixtureData(for: "Tx.Select")
        let decoded = try FrameDecoder().decode(Spec.Tx.Select.self, from: input)
        let expected = Spec.Tx.Select()
        #expect(decoded == expected)
    }

    @Test("Spec.Tx.SelectOk verify decode bytes")
    func amqpTxSelectOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Tx.SelectOk")
        let decoded = try FrameDecoder().decode(Spec.Tx.SelectOk.self, from: input)
        let expected = Spec.Tx.SelectOk()
        #expect(decoded == expected)
    }

    @Test("Spec.Tx.Commit verify decode bytes")
    func amqpTxCommitDecodeBytes() async throws {
        let input = try fixtureData(for: "Tx.Commit")
        let decoded = try FrameDecoder().decode(Spec.Tx.Commit.self, from: input)
        let expected = Spec.Tx.Commit()
        #expect(decoded == expected)
    }

    @Test("Spec.Tx.CommitOk verify decode bytes")
    func amqpTxCommitOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Tx.CommitOk")
        let decoded = try FrameDecoder().decode(Spec.Tx.CommitOk.self, from: input)
        let expected = Spec.Tx.CommitOk()
        #expect(decoded == expected)
    }

    @Test("Spec.Tx.Rollback verify decode bytes")
    func amqpTxRollbackDecodeBytes() async throws {
        let input = try fixtureData(for: "Tx.Rollback")
        let decoded = try FrameDecoder().decode(Spec.Tx.Rollback.self, from: input)
        let expected = Spec.Tx.Rollback()
        #expect(decoded == expected)
    }

    @Test("Spec.Tx.RollbackOk verify decode bytes")
    func amqpTxRollbackOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Tx.RollbackOk")
        let decoded = try FrameDecoder().decode(Spec.Tx.RollbackOk.self, from: input)
        let expected = Spec.Tx.RollbackOk()
        #expect(decoded == expected)
    }

}

@Suite struct ConfirmDecode {
    @Test("Spec.Confirm.Select verify decode bytes")
    func amqpConfirmSelectDecodeBytes() async throws {
        let input = try fixtureData(for: "Confirm.Select")
        let decoded = try FrameDecoder().decode(Spec.Confirm.Select.self, from: input)
        let expected = Spec.Confirm.Select()
        #expect(decoded == expected)
    }

    @Test("Spec.Confirm.SelectOk verify decode bytes")
    func amqpConfirmSelectOkDecodeBytes() async throws {
        let input = try fixtureData(for: "Confirm.SelectOk")
        let decoded = try FrameDecoder().decode(Spec.Confirm.SelectOk.self, from: input)
        let expected = Spec.Confirm.SelectOk()
        #expect(decoded == expected)
    }

}

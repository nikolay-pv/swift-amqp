//
//  AMQPChannel.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 28.09.2024.
//

// TODO: how to enforce single use without an actor - keep in mind this must be stored in a dict in Connection?
public actor AMQPChannel {
    init(id: Int) {
        self.id = id
    }

    private(set) var id: Int

    func open() async throws {

    }
}

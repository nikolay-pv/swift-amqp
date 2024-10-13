//
//  AMQPConfiguration.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 28.09.2024.
//

public struct AMQPConfiguration: Sendable {
    public var host: String
    public var port: Int
    public var username: String
    public var password: String

    public static let `default`: AMQPConfiguration =
        .init(host: "localhost", port: 5672, username: "guest", password: "guest")
}

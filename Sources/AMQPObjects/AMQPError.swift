//
//  AMQPError.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 28.09.2024.
//

// TODO: improve this (& +messaging + internal / external split)
enum AMQPError {
    enum DecodingError: Error {
        case invalidFrameType
        case unknownClassAndMethod(class: UInt16, method: UInt16)
        case unknownFrameType(_ type: UInt8)
    }
//    case invalidFrame
//    case invalidFrameSize
//    case invalidFrameField
//    case invalidFrameFieldValue
//    case invalidFrameFieldValueLength
//    case invalidFrameFieldValueEncoding
//    case invalidFrameFieldValueEncodingLength
//    case invalidFrameFieldValueEncodingString
}

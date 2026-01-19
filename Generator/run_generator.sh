#!/bin/bash
DIR="$(pwd)/$(dirname "$0")"
python "$DIR"/codegen.py 'header' "$DIR"/rabbitmq_codegen/amqp-rabbitmq-0.9.1.json "$DIR"/../Sources/Spec/Spec.swift
python "$DIR"/codegen.py 'body'   "$DIR"/rabbitmq_codegen/amqp-rabbitmq-0.9.1.json "$DIR"/../Sources/Spec/Spec+FrameCodable.swift
# tests
python "$DIR"/testgen.py 'header' "$DIR"/rabbitmq_codegen/amqp-rabbitmq-0.9.1.json "$DIR"/../Tests/AMQPTests/Spec/CodableRoundtrip.swift
python "$DIR"/testgen.py 'body'   "$DIR"/rabbitmq_codegen/amqp-rabbitmq-0.9.1.json "$DIR"/../Tests/AMQPTests/Spec/CodableVerification.swift
# format
swift format format --in-place --configuration "$DIR"/../.swift-format "$DIR"/../Sources/Spec/Spec.swift "$DIR"/../Sources/Spec/Spec+FrameCodable.swift "$DIR"/../Tests/AMQPTests/Spec/CodableRoundtrip.swift "$DIR"/../Tests/AMQPTests/Spec/CodableVerification.swift

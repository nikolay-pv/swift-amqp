#!/usr/bin/env python

# this generator requires https://github.com/rabbitmq/rabbitmq-server/tree/main/deps/rabbitmq_codegen to work
from shared.utilities import *
from rabbitmq_codegen.amqp_codegen import *

import pika

# --------------------------------------------------------------------------------

def gen_swift_tests_from_spec(spec: AmqpSpec):
    def header(): 
        print("import Testing")
        print("@testable import RabbitMQ")
        print("")
        print("func tester<T>(_ object: T) throws where T : AMQPCodable & Equatable {")
        print("    let binary = try FrameEncoder().encode(object)")
        print("    let decoded = try FrameDecoder().decode(T.self, from: binary)")
        print("    #expect(decoded == object)")
        print("}")
    
    def generate_value(spec, domain: str):
        t = swift_type(spec, domain)
        if t == "String":
            return f"\"FooBar\""
        if t == "[String: FieldValue]":
            return ".init()"
        if t.startswith("Int"):
            return "1"
        if t == "Bool":
            return "true"
        raise RuntimeError(f"Unknown domain - type: {domain} - {t}")

    def amqp_classes_and_methods():
        for c in spec.classes:
            print()
            print(f"@Suite struct {struct_name(c.name)} {{")
            for m in c.allMethods():
                must_be_specified = [a for a in m.arguments if a.defaultvalue is None]
                obj = f"AMQP.{struct_name(c.name)}.{struct_name(m.name)}"
                print(f"    @Test(\"{obj} default encoding/decoding roundtrip\")")
                print(f"    func amqp{struct_name(c.name)}{struct_name(m.name)}Encoding() async throws {{")
                if not len(must_be_specified):
                    print(f"        let object = {obj}()")
                else:
                    args = [f"{variable_name(a.name)}: {generate_value(spec, a.domain)}" for a in must_be_specified]
                    print(f"        let object = {obj}({', '.join(args)})")
                print(f"        try tester(object)")
                print("    }")
                print()

            print("}")

    header()
    amqp_classes_and_methods()


def gen_swift_api(specPath):
    gen_swift_tests_from_spec(AmqpSpec(specPath))


def gen_swift_impl(specPath):
    pass


if __name__ == "__main__":
    do_main(gen_swift_api, gen_swift_impl)

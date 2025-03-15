#!/usr/bin/env python

# this generator requires https://github.com/rabbitmq/rabbitmq-server/tree/main/deps/rabbitmq_codegen to work
from shared.utilities import *
from rabbitmq_codegen.amqp_codegen import *


# --------------------------------------------------------------------------------


def gen_swift_tests(spec: AmqpSpec):
    def header():
        print_file_header()
        print("import Testing")
        print("")
        print("@testable import AMQP")
        print("")

    def generate_value(spec, domain: str):
        t = swift_type(spec, domain)
        if t == "String":
            return f'"FooBar"'
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
            print(f"@Suite struct {struct_name(c.name)}Coding {{")
            for m in c.allMethods():
                must_be_specified = [a for a in m.arguments if a.defaultvalue is None]
                obj = f"Spec.{struct_name(c.name)}.{struct_name(m.name)}"
                print(f'    @Test("{obj} default encoding/decoding roundtrip")')
                print(
                    f"    func amqp{struct_name(c.name)}{struct_name(m.name)}Coding() async throws {{"
                )
                if not len(must_be_specified):
                    print(f"        let object = {obj}()")
                else:
                    args = [
                        f"{variable_name(a.name)}: {generate_value(spec, a.domain)}"
                        for a in must_be_specified
                    ]
                    print(f"        let object = {obj}({', '.join(args)})")
                print("         let binary = try FrameEncoder().encode(object)")
                print("         #expect(binary.count == object.bytesCount)")
                print(
                    f"         let decoded = try FrameDecoder().decode({obj}.self, from: binary)"
                )
                print("         #expect(decoded == object)")
                print("    }")
                print()

            print("}")

    header()
    amqp_classes_and_methods()


def gen_swift_verify_tests(spec: AmqpSpec):
    def header():
        print_file_header()
        print("import Testing")
        print("")
        print("@testable import AMQP")

    def generate_value(spec, domain: str):
        t = swift_type(spec, domain)
        if t == "String":
            return f'"FooBar"'
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
            print(f"@Suite struct {struct_name(c.name)}Decode {{")
            for m in c.allMethods():
                must_be_specified = [a for a in m.arguments if a.defaultvalue is None]
                obj = f"{struct_name(c.name)}.{struct_name(m.name)}"
                print(f'    @Test("Spec.{obj} verify decode bytes")')
                print(
                    f"    func amqp{struct_name(c.name)}{struct_name(m.name)}DecodeBytes() async throws {{"
                )
                print(f'        let input = try fixtureData(for: "{obj}")')
                print(
                    f"        let decoded = try FrameDecoder().decode(Spec.{obj}.self, from: input)"
                )
                if not len(must_be_specified):
                    print(f"        let expected = Spec.{obj}()")
                else:
                    args = [
                        f"{variable_name(a.name)}: {generate_value(spec, a.domain)}"
                        for a in must_be_specified
                    ]
                    print(f"        let expected = Spec.{obj}({', '.join(args)})")
                print(f"        #expect(decoded == expected)")
                print("    }")
                print()

            print("}")

    header()
    amqp_classes_and_methods()


if __name__ == "__main__":
    do_main(
        lambda x: gen_swift_tests(AmqpSpec(x)),
        lambda x: gen_swift_verify_tests(AmqpSpec(x)),
    )

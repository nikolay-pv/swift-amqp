#!/usr/bin/env python

# this generator requires https://github.com/rabbitmq/rabbitmq-server/tree/main/deps/rabbitmq_codegen to work

from shared.utilities import *
from rabbitmq_codegen.amqp_codegen import *


def gen_swift_api_from_spec(spec: AmqpSpec):
    def protocols():
        print(
            """protocol AMQPObjectProtocol: Equatable {
    var amqpName: String { get }
}

protocol AMQPClassProtocol: AMQPObjectProtocol {
    var amqpClassId: UInt16 { get }
}

protocol AMQPPropertiesProtocol: AMQPObjectProtocol, Hashable { }

protocol AMQPMethodProtocol: AMQPClassProtocol {
    var amqpMethodId: UInt16 { get }
}"""
        )

    def FieldValueEnum():
        print("    public typealias Table = [String: FieldValue]")
        print("")
        print("    public enum FieldValue: Equatable, Hashable, CaseIterable, Sendable {")
        print("        public static let allCases: [Self] = [")
        print("            .long(0),")
        print("            .decimal(0, 0),")
        print('            .longstr(""),')
        print("            .timestamp(Date.distantPast),")
        print("            .table([:]),")
        print("            .void")
        print("        ]")
        print()
        print("        case long(Int32),")
        print("        decimal(UInt8, Int32),")
        print("        longstr(String),")
        print("        timestamp(Date),")
        print("        table(Table),")
        print("        void")
        print("")
        print("        var type: UInt8 {")
        print("            switch self {")
        print('            case .long: return Character("I").asciiValue!')
        print('            case .decimal: return Character("D").asciiValue!')
        print('            case .longstr: return Character("S").asciiValue!')
        print('            case .timestamp: return Character("T").asciiValue!')
        print('            case .table: return Character("F").asciiValue!')
        print('            case .void: return Character("V").asciiValue!')
        print("            }")
        print("        }")
        print("")
        print("        var bytesCount: UInt32 {")
        print("            switch self {")
        print("            case .long: return 4")
        print("            case .decimal: return 5")
        print("            case .longstr(let value): return value.longBytesCount")
        print("            case .timestamp: return 8")
        print("            case .table(let value): return value.bytesCount")
        print("            case .void: return 1")
        print("            }")
        print("        }")
        print("    }")

    def header():
        print_file_header()
        print("import Foundation")

    def amqp_constants():
        print()
        print("    public struct ProtocolLevel {")
        print(f"        static let MAJOR = {spec.major}")
        print(f"        static let MINOR = {spec.minor}")
        print(f"        static let REVISION = {spec.revision}")
        print(f"        static let PORT = {spec.port}")
        print("    }")
        print()
        for c, v, _ in spec.constants:
            print(f"    static let {constant_name(c)} = {v}")

    def amqp_classes_and_methods():
        for c in spec.classes:
            print()
            print(f"    public struct {struct_name(c.name)} : AMQPClassProtocol {{")
            print(f"        public var amqpClassId: UInt16 {{ {c.index} }}")
            print(f'        public var amqpName: String {{ "{c.name}" }}')
            for m in c.allMethods():
                print()
                print(f"        public struct {struct_name(m.name)} : AMQPMethodProtocol {{")
                for a in m.arguments:
                    if a.defaultvalue is None:
                        print(f"           private(set) var {variable_name(a.name)}: {swift_type(spec, a.domain)}")
                    else:
                        print(f"           private(set) var {variable_name(a.name)}: {swift_type(spec, a.domain)} = {default_value(spec, a.domain, a.defaultvalue)}")
                print()
                print(f"           public var amqpClassId: UInt16 {{ {c.index} }}")
                print(f"           public var amqpMethodId: UInt16 {{ {m.index} }}")
                print(f'           public var amqpName: String {{ "{c.name}.{m.name}" }}')
                print("        }")
            print("    }")

    def specific_properties(c):
        structName = struct_name(c.name)

        print()
        print(f"    public struct {structName}Properties : AMQPPropertiesProtocol {{")
        for f in c.fields:
            print(f"        private(set) var {variable_name(f.name)}: {swift_type(spec, f.domain)}")

        print()
        print(f"        public var amqpClassId: UInt16 {{ {c.index} }}")
        print(f'        public var amqpName: String {{ "{c.name}" }}')
        print("    }")

    def amqp_properties_classes():
        for c in spec.classes:
            if c.hasContentProperties:
                specific_properties(c)

    def amqp_spec():
        print("public enum AMQP {")

        FieldValueEnum()
        amqp_constants()
        amqp_classes_and_methods()
        amqp_properties_classes()

        print("}")

    header()
    print()
    protocols()
    print()
    amqp_spec()


# --------------------------------------------------------------------------------

def as_bool_literal(val: bool):
    return "true" if val else "false"

def gen_swift_impl_from_spec(spec: AmqpSpec):

    def header():
        print_file_header()
        print("import Foundation")
        print()
        print("fileprivate typealias FieldValue = AMQP.FieldValue")

    def encode_extensions():
        for c in spec.allClasses():
            for m in c.allMethods():
                print()
                print(f"extension AMQP.{struct_name(c.name)}.{struct_name(m.name)} : AMQPCodable {{")
                print("    func encode(to encoder: AMQPEncoder) throws {")
                for a in m.arguments:
                    t = spec.resolveDomain(a.domain)
                    if t == "shortstr" or t == "longstr":
                        is_long = t == "longstr"
                        print(f"        try encoder.encode({variable_name(a.name)}, isLong: {as_bool_literal(is_long)})")
                    else:
                        print(f"        try encoder.encode({variable_name(a.name)})")
                print("    }")
                print()
                print("    init(from decoder: AMQPDecoder) throws {")
                lines = []
                bytes_count = ["4"] # the class and frame ids
                for a in m.arguments:
                    bytes_count.append(get_bytes_count(spec, a.name, a.domain))
                    t = spec.resolveDomain(a.domain)
                    if t == "shortstr" or t == "longstr":
                        is_long = t == "longstr"
                        lines.append(f"            {variable_name(a.name, False)}: try decoder.decode({swift_type(spec, a.domain)}.self, isLong: {as_bool_literal(is_long)})")
                    else:
                        lines.append(f"            {variable_name(a.name, False)}: try decoder.decode({swift_type(spec, a.domain)}.self)")
                if len(lines):
                    print(f"        self.init(")
                    print(",\n".join(lines))
                    print(f"        )")
                else:
                    print("        self.init()")
                print("    }")
                print()
                bc = " + ".join(sorted(bytes_count)) # optimization for compiler
                print("    var bytesCount: UInt32 { " + bc + " }")
                print("}")

        print()
        print("extension AMQP {")
        print("    typealias Factory = @Sendable (any AMQPDecoder) throws -> any AMQPCodable")
        print("    static func makeFactory(with classId: UInt16, and methodId: UInt16) throws -> Factory {")
        print("        switch(classId, methodId) {")
        for c in spec.allClasses():
            for m in c.allMethods():
                print(f"        case ({c.index}, {m.index}): return AMQP.{struct_name(c.name)}.{struct_name(m.name)}.init")
        print("        default: throw AMQPError.DecodingError.unknownClassAndMethod(class: classId, method: methodId)")
        print("        }")
        print("    }")
        print("}")

    def decode_extensions():
        pass

    header()
    encode_extensions()
    decode_extensions()


# --------------------------------------------------------------------------------


def gen_swift_api(specPath):
    gen_swift_api_from_spec(AmqpSpec(specPath))


def gen_swift_impl(specPath):
    gen_swift_impl_from_spec(AmqpSpec(specPath))


if __name__ == "__main__":
    do_main(gen_swift_api, gen_swift_impl)

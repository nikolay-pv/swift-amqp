#!/usr/bin/env python

# this generator requires https://github.com/rabbitmq/rabbitmq-server/tree/main/deps/rabbitmq_codegen to work

from shared.utilities import *
from rabbitmq_codegen.amqp_codegen import *


def gen_swift_api(spec: AmqpSpec):
    def protocols():
        print(
            """protocol AMQPObjectProtocol: Equatable {
    var amqpName: String { get }
}

protocol AMQPClassProtocol: AMQPObjectProtocol {
    var amqpClassId: UInt16 { get }
}

protocol AMQPPropertiesProtocol: AMQPObjectProtocol, Hashable {}

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
        print("            .void,")
        print("        ]")
        print()
        print("        case long(Int32),")
        print("            decimal(UInt8, Int32),")
        print("            longstr(String),")
        print("            timestamp(Date),")
        print("            table(Table),")
        print("            void")
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
        print(f"        static let MAJOR: UInt8 = {spec.major}")
        print(f"        static let MINOR: UInt8 = {spec.minor}")
        print(f"        static let REVISION: UInt8 = {spec.revision}")
        print(f"        static let PORT = {spec.port}")
        print("    }")
        print()
        for c, v, _ in spec.constants:
            c = constant_name(c)
            if c in ["FrameMethod", "FrameHeader", "FrameBody", "FrameHeartbeat", "FrameEnd"]:
                c += ": UInt8"
            print(f"    static let {c} = {v}")

    def amqp_classes_and_methods():
        for c in spec.classes:
            print()
            print(f"    public struct {struct_name(c.name)}: AMQPClassProtocol {{")
            print(f"        public var amqpClassId: UInt16 {{ {c.index} }}")
            print(f'        public var amqpName: String {{ "{c.name}" }}')
            for m in c.allMethods():
                print()
                print(f"        public struct {struct_name(m.name)}: AMQPMethodProtocol {{")
                for a in m.arguments:
                    if a.defaultvalue is None:
                        print(f"            private(set) var {variable_name(a.name)}: {swift_type(spec, a.domain)}")
                    else:
                        print(f"            private(set) var {variable_name(a.name)}: {swift_type(spec, a.domain)} = {default_value(spec, a.domain, a.defaultvalue)}")
                print()
                print(f"            public var amqpClassId: UInt16 {{ {c.index} }}")
                print(f"            public var amqpMethodId: UInt16 {{ {m.index} }}")
                print(f'            public var amqpName: String {{ "{c.name}.{m.name}" }}')
                print("        }")
            print("    }")

    def specific_properties(c):
        structName = struct_name(c.name)

        print()
        print(f"    public struct {structName}Properties: AMQPPropertiesProtocol {{")
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
        print("public enum Spec {")

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

def gen_swift_impl(spec: AmqpSpec):

    def header():
        print_file_header()
        print("import Foundation")
        print()
        print("private typealias FieldValue = Spec.FieldValue")

    def pack_encode_bits(bits_to_pack):
        if len(bits_to_pack) == 0:
            return
        if len(bits_to_pack) == 1:
            print(f"        try encoder.encode({variable_name(bits_to_pack[0].name)})")
            return
        print(f"        var bitPack: UInt8 = 0")
        if len(bits_to_pack) > 8:
            raise RuntimeError("packing more than 8 bits is not implemented")
        for k, a in enumerate(bits_to_pack):
            print(f"        if {variable_name(a.name)} {{ bitPack |= 1 << {k} }}")
        print(f"        try encoder.encode(bitPack)")

    def pack_decode_bits(bits_to_unpack):
        if len(bits_to_unpack) == 0:
            return
        if len(bits_to_unpack) == 1:
            a = bits_to_unpack[0]
            print(f"        let {variable_name(a.name, True)} = try decoder.decode({swift_type(spec, a.domain)}.self)")
            return
        print(f"        let bitPack: UInt8 = try decoder.decode(UInt8.self)")
        if len(bits_to_unpack) > 8:
            raise RuntimeError("packing more than 8 bits is not implemented")
        for k, a in enumerate(bits_to_unpack):
            print(f"        let {variable_name(a.name, True)}: Bool = ((bitPack & (1 << {k})) != 0)")

    def encode_extensions():
        for c in spec.allClasses():
            for m in c.allMethods():
                print()
                print(f"extension Spec.{struct_name(c.name)}.{struct_name(m.name).strip()}: AMQPCodable {{")
                print("    func encode(to encoder: AMQPEncoder) throws {")
                bits_to_pack = []
                for a in m.arguments:
                    t = spec.resolveDomain(a.domain)
                    if t == "bit":
                        bits_to_pack.append(a)
                        continue
                    else:
                        pack_encode_bits(bits_to_pack)
                        bits_to_pack = []
                    if t == "shortstr" or t == "longstr":
                        is_long = t == "longstr"
                        print(f"        try encoder.encode({variable_name(a.name)}, isLong: {as_bool_literal(is_long)})")
                    else:
                        print(f"        try encoder.encode({variable_name(a.name)})")
                pack_encode_bits(bits_to_pack)
                bits_to_pack = []
                print("    }")
                print()
                print("    init(from decoder: AMQPDecoder) throws {")
                bytes_count = ["4"] # the class and frame ids
                bits_to_unpack = []
                for a in m.arguments:
                    bytes_count.append(get_bytes_count(spec, a.name, a.domain))
                    t = spec.resolveDomain(a.domain)
                    if t == "bit":
                        bits_to_unpack.append(a)
                        continue
                    else:
                        pack_decode_bits(bits_to_unpack)
                        bits_to_unpack = []
                    if t == "shortstr" or t == "longstr":
                        is_long = t == "longstr"
                        print(f"        let {variable_name(a.name, False)} = try decoder.decode({swift_type(spec, a.domain)}.self, isLong: {as_bool_literal(is_long)})")
                    else:
                        print(f"        let {variable_name(a.name, False)} = try decoder.decode({swift_type(spec, a.domain)}.self)")
                pack_decode_bits(bits_to_unpack)
                bits_to_unpack = []
                if not len(m.arguments):
                    print("        self.init()")
                else:
                    print(f"        self.init(")
                    print(",\n".join([f"            {variable_name(a.name, False)}: {variable_name(a.name, True)}" for a in m.arguments]))
                    print(f"        )")
                print("    }")
                print()
                bc = " + ".join(sorted(bytes_count)) # optimization for compiler
                print("    var bytesCount: UInt32 { " + bc + " }")
                print("}")

        print()
        print("extension Spec {")
        print("    typealias Factory = @Sendable (any AMQPDecoder) throws -> any AMQPCodable")
        print("    static func makeFactory(with classId: UInt16, and methodId: UInt16) throws -> Factory {")
        print("        switch (classId, methodId) {")
        for c in spec.allClasses():
            for m in c.allMethods():
                print(f"        case ({c.index}, {m.index}): return Spec.{struct_name(c.name)}.{struct_name(m.name)}.init")
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

if __name__ == "__main__":
    do_main(lambda x: gen_swift_api(AmqpSpec(x)), lambda x: gen_swift_impl(AmqpSpec(x)))

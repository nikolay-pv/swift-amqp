#!/usr/bin/env python

# this generator requires https://github.com/rabbitmq/rabbitmq-server/tree/main/deps/rabbitmq_codegen to work

from shared.utilities import *
from rabbitmq_codegen.amqp_codegen import *


def gen_swift_api(spec: AmqpSpec):
    def protocols():
        print(
            """protocol AMQPObjectProtocol: Equatable, Sendable {
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
        # based on the first column from here: https://www.rabbitmq.com/amqp-0-9-1-errata#section_3
        # enum case, native Swift type, kind, size
        field_values_definitions = [
            ("bool", "Bool", "t", "1"),  # stored as Int8
            ("int8", "Int8", "b", "1"),
            ("uint8", "UInt8", "B", "1"),
            # conflicting in spec and implementation, fallback to implementation
            ("int16", "Int16", "s", "2"),
            ("uint16", "UInt16", "u", "2"),
            ("int32", "Int32", "I", "4"),
            ("uint32", "UInt32", "i", "4"),
            # conflicting in spec and implementation, fallback to implementation
            ("int64", "Int64", "l", "8"),
            # ("uint64", "UInt64", "l", "8"),
            ("f32", "Float", "f", "4"),
            ("f64", "Double", "d", "8"),
            ("decimal", "UInt8, Int32", "D", "5"),
            # ("shortstr", "String", "s", "UInt32(value.shortBytesCount)"),
            ("longstr", "String", "S", "value.longBytesCount"),
            (
                "array",
                "[FieldValue]",
                "A",
                "value.reduce(into: 0) { $0 += $1.bytesCount }",
            ),
            ("timestamp", "Date", "T", "8"),  # stored as uint64
            ("table", "Table", "F", "value.bytesCount"),
            ("bytes", "[UInt8]", "x", "UInt32(value.count)"),
            ("void", "", "V", "1"),
        ]

        def get_init_value(case: str, type: str) -> str:
            if case == "decimal":
                return f"0,0"
            elif case == "timestamp":
                return "Date.distantPast"
            elif case == "table":
                return "[:]"
            return f"{type}.init()"

        print("    public typealias Table = [String: FieldValue]")
        print("")
        print(
            "    public enum FieldValue: Equatable, Hashable, CaseIterable, Sendable {"
        )
        print("        public static let allCases: [Self] = [")
        for case, type, _, _ in field_values_definitions:
            if len(type):
                print(f"            .{case}({get_init_value(case, type)}),")
            else:
                print(f"            .{case},")
        print("        ]")
        print()
        for case, type, _, _ in field_values_definitions:
            if len(type):
                print(f"        case {case}({type})")
            else:
                print(f"        case {case}")
        print("")
        print("        var type: UInt8 {")
        print("            switch self {")
        for case, _, kind, _ in field_values_definitions:
            print(f'            case .{case}: return Character("{kind}").asciiValue!')
        print("            }")
        print("        }")
        print("")
        print("        var bytesCount: UInt32 {")
        print("            // 1 extra byte to store the type info")
        print("            switch self {")
        for case, _, kind, size in field_values_definitions:
            if "value" in size:
                addition = (
                    "" if case not in ["array", "bytes"] else " + 4 // 4 for length"
                )
                print(
                    f"            case .{case}(let value): return {size} + 1{addition}"
                )
            else:
                print(f"            case .{case}: return {size} + 1")
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
        for c, v, constant_class in spec.constants:
            if "error" in constant_class:
                continue
            c = constant_name(c)
            if c in [
                "FrameMethod",
                "FrameHeader",
                "FrameBody",
                "FrameHeartbeat",
                "FrameEnd",
            ]:
                c += ": UInt8"
            print(f"    static let {c} = {v}")

        print("\n    enum SoftError: Int, Error {")
        for c, v, constant_class in spec.constants:
            if "soft-error" in constant_class:
                c = as_camel_case(False, c)
                print(f"    case {c} = {v}")
        print("    }")
        print("\n    enum HardError: Int, Error {")
        for c, v, constant_class in spec.constants:
            if "hard-error" in constant_class:
                c = as_camel_case(False, c)
                print(f"    case {c} = {v}")
        print("    }")

    def amqp_classes_and_methods():
        for c in spec.classes:
            print()
            print(f"    public struct {struct_name(c.name)}: AMQPClassProtocol {{")
            print(f"        public var amqpClassId: UInt16 {{ {c.index} }}")
            print(f'        public var amqpName: String {{ "{c.name}" }}')
            for m in c.allMethods():
                print()
                print(
                    f"        public struct {struct_name(m.name)}: AMQPMethodProtocol {{"
                )
                for a in m.arguments:
                    if a.defaultvalue is None:
                        print(
                            f"            private(set) var {variable_name(a.name)}: {swift_type(spec, a.domain)}"
                        )
                    else:
                        print(
                            f"            private(set) var {variable_name(a.name)}: {swift_type(spec, a.domain)} = {default_value(spec, a.domain, a.defaultvalue)}"
                        )
                print()
                print(f"            public var amqpClassId: UInt16 {{ {c.index} }}")
                print(f"            public var amqpMethodId: UInt16 {{ {m.index} }}")
                print(
                    f'            public var amqpName: String {{ "{c.name}.{m.name}" }}'
                )
                print("        }")
            print("    }")

    def specific_properties(c):
        structName = struct_name(c.name)

        print()
        print(f"    public struct {structName}Properties: AMQPPropertiesProtocol {{")
        for f in c.fields:
            print(
                f"        private(set) var {variable_name(f.name)}: {swift_type(spec, f.domain)}?"
            )

        print()
        print(f"        public var amqpClassId: UInt16 {{ {c.index} }}")
        print(f'        public var amqpName: String {{ "{c.name}" }}')
        print("    }")

    def amqp_properties_classes():
        for c in spec.classes:
            if c.hasContentProperties:
                specific_properties(c)

    def amqp_spec():
        print("// swiftlint:disable nesting type_body_length")
        print("public enum Spec {")

        FieldValueEnum()
        amqp_constants()
        amqp_classes_and_methods()
        amqp_properties_classes()

        print("}")
        print("// swiftlint:enable nesting type_body_length")

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

    def pack_decode_bits(bits_to_unpack) -> int:
        """returns number of bytes it would need"""
        if len(bits_to_unpack) == 0:
            return None
        if len(bits_to_unpack) == 1:
            a = bits_to_unpack[0]
            print(
                f"        let {variable_name(a.name, True)} = try decoder.decode({swift_type(spec, a.domain)}.self)"
            )
            return 1
        print(f"        let bitPack: UInt8 = try decoder.decode(UInt8.self)")
        if len(bits_to_unpack) > 8:
            raise RuntimeError("packing more than 8 bits is not implemented")
        for k, a in enumerate(bits_to_unpack):
            print(
                f"        let {variable_name(a.name, True)}: Bool = ((bitPack & (1 << {k})) != 0)"
            )
        return 1  # can't pack more than 8 bits for now

    def encode_extensions():
        for c in spec.allClasses():
            for m in c.allMethods():
                print()
                print(
                    f"extension Spec.{struct_name(c.name)}.{struct_name(m.name).strip()}: FrameCodable {{"
                )
                print("    func encode(to encoder: FrameEncoderProtocol) throws {")
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
                        print(
                            f"        try encoder.encode({variable_name(a.name)}, isLong: {as_bool_literal(is_long)})"
                        )
                    else:
                        print(f"        try encoder.encode({variable_name(a.name)})")
                pack_encode_bits(bits_to_pack)
                bits_to_pack = []
                print("    }")
                print()
                print("    init(from decoder: FrameDecoderProtocol) throws {")
                bytes_count = []
                bits_to_unpack = []
                for a in m.arguments:
                    t = spec.resolveDomain(a.domain)
                    if t == "bit":
                        bits_to_unpack.append(a)
                        continue
                    else:
                        # not encoding bits, check if there are any bits to encode and do that
                        serialized_size = pack_decode_bits(bits_to_unpack)
                        bits_to_unpack = []
                        if serialized_size:
                            bytes_count.append(str(serialized_size))
                    bytes_count.append(get_bytes_count(spec, a.name, a.domain))
                    if t == "shortstr" or t == "longstr":
                        is_long = t == "longstr"
                        print(
                            f"        let {variable_name(a.name, False)} = try decoder.decode({swift_type(spec, a.domain)}.self, isLong: {as_bool_literal(is_long)})"
                        )
                    else:
                        print(
                            f"        let {variable_name(a.name, False)} = try decoder.decode({swift_type(spec, a.domain)}.self)"
                        )
                serialized_size = pack_decode_bits(bits_to_unpack)
                bits_to_unpack = []
                if serialized_size != None:
                    bytes_count.append(str(serialized_size))
                if not len(m.arguments):
                    print("        self.init()")
                else:
                    print(f"        self.init(")
                    print(
                        ",\n".join(
                            [
                                f"            {variable_name(a.name, False)}: {variable_name(a.name, True)}"
                                for a in m.arguments
                            ]
                        )
                    )
                    print(f"        )")
                print("    }")
                print()
                bc = " + ".join(sorted(bytes_count))  # optimization for compiler
                print("    var bytesCount: UInt32 { " + (bc if len(bc) else "0") + " }")
                print("}")

        print()
        print("extension Spec {")
        print(
            "    typealias Factory = @Sendable (any FrameDecoderProtocol) throws -> any FrameCodable\n"
        )
        print("    // swiftlint:disable:next all")
        print(
            "    static func makeFactory(with classId: UInt16, and methodId: UInt16) throws -> Factory {"
        )
        print("        switch (classId, methodId) {")
        for c in spec.allClasses():
            for m in c.allMethods():
                print(
                    f"        case ({c.index}, {m.index}): return Spec.{struct_name(c.name)}.{struct_name(m.name)}.init"
                )
        print(
            "        default: throw FramingError.unknownClassAndMethod(class: classId, method: methodId)"
        )
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

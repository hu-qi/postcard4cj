package postcard4cj.dynamic

import postcard4cj.flavors.*
import postcard4cj.schema.*
import std.math.numeric.*
import std.unittest.*
import std.unittest.testmacro.*

private func telemetrySchema(): NamedType {
    return structSchema("Telemetry", [
        NamedValue("id", uint32Schema()),
        NamedValue("temperature", float32Schema()),
        NamedValue("note", optionSchema(stringSchema())),
        NamedValue("samples", sequenceSchema(int16Schema()))
    ])
}

private func telemetryValue(): DynamicValue {
    return DynamicValue.StructValue([
        DynamicField("id", DynamicValue.UnsignedValue(BigInt(300i64))),
        DynamicField("temperature", DynamicValue.FloatValue(12.5f64)),
        DynamicField("note", dynamicSome(DynamicValue.StringValue("ok"))),
        DynamicField("samples", DynamicValue.SequenceValue([
            DynamicValue.SignedValue(BigInt(-1i64)),
            DynamicValue.SignedValue(BigInt(0i64)),
            DynamicValue.SignedValue(BigInt(1i64)),
            DynamicValue.SignedValue(BigInt(128i64))
        ]))
    ])
}

private func commandSchema(): NamedType {
    return enumSchema("Command", [
        NamedVariant("Ping", DataModelVariant.UnitVariant),
        NamedVariant("SetSpeed", DataModelVariant.NewtypeVariant(uint16Schema())),
        NamedVariant("Rename", DataModelVariant.TupleVariant([
            stringSchema(), boolSchema()
        ]))
    ])
}

@Test
public class DynamicCodecTest {
    @TestCase
    public func telemetryMatchesRustPostcardVector(): Unit {
        let expected: Array<UInt8> = [
            0xacu8, 0x02u8,
            0x00u8, 0x00u8, 0x48u8, 0x41u8,
            0x01u8, 0x02u8, 0x6fu8, 0x6bu8,
            0x04u8, 0x01u8, 0x00u8, 0x02u8, 0x80u8, 0x02u8
        ]
        @Assert(toByteArrayDynamic(telemetrySchema(), telemetryValue()), expected)

        let decoded = fromByteArrayDynamic(telemetrySchema(), expected)
        match (decoded) {
            case DynamicValue.StructValue(fields) =>
                @Assert(fields.size, 4)
                match (fields[0].value) {
                    case DynamicValue.UnsignedValue(value) => @Assert(value, BigInt(300i64))
                    case _ => throw IllegalStateException("Expected id")
                }
                match (fields[2].value) {
                    case DynamicValue.OptionValue(option) =>
                        match (option.value) {
                            case Some(DynamicValue.StringValue(value)) => @Assert(value, "ok")
                            case _ => throw IllegalStateException("Expected note")
                        }
                    case _ => throw IllegalStateException("Expected option")
                }
            case _ => throw IllegalStateException("Expected struct")
        }
    }

    @TestCase
    public func optionPreservesNoneVersusSomeUnit(): Unit {
        let schema = optionSchema(unitSchema())
        @Assert(toByteArrayDynamic(schema, dynamicNone()), [0x00u8])
        @Assert(toByteArrayDynamic(schema, dynamicSome(DynamicValue.UnitValue)), [0x01u8])

        match (fromByteArrayDynamic(schema, [0x01u8])) {
            case DynamicValue.OptionValue(option) =>
                match (option.value) {
                    case Some(DynamicValue.UnitValue) => ()
                    case _ => throw IllegalStateException("Expected Some(Unit)")
                }
            case _ => throw IllegalStateException("Expected Option")
        }
    }

    @TestCase
    public func mapSupportsNonStringKeys(): Unit {
        let schema = mapSchema(uint8Schema(), stringSchema())
        let value = DynamicValue.MapValue([
            DynamicEntry(
                DynamicValue.UnsignedValue(BigInt(1i64)),
                DynamicValue.StringValue("a")
            ),
            DynamicEntry(
                DynamicValue.UnsignedValue(BigInt(2i64)),
                DynamicValue.StringValue("b")
            )
        ])
        let expected: Array<UInt8> = [
            0x02u8, 0x01u8, 0x01u8, 0x61u8,
            0x02u8, 0x01u8, 0x62u8
        ]
        @Assert(toByteArrayDynamic(schema, value), expected)
        match (fromByteArrayDynamic(schema, expected)) {
            case DynamicValue.MapValue(entries) =>
                @Assert(entries.size, 2)
                match (entries[1].key) {
                    case DynamicValue.UnsignedValue(key) => @Assert(key, BigInt(2i64))
                    case _ => throw IllegalStateException("Expected integer key")
                }
            case _ => throw IllegalStateException("Expected map")
        }
    }

    @TestCase
    public func enumVariantsUseDeclarationOrder(): Unit {
        let schema = commandSchema()
        let ping = DynamicValue.EnumValue(
            DynamicEnumValue("Ping", DynamicEnumPayload.UnitPayload)
        )
        let speed = DynamicValue.EnumValue(DynamicEnumValue(
            "SetSpeed",
            DynamicEnumPayload.NewtypePayload(
                DynamicValue.UnsignedValue(BigInt(128i64))
            )
        ))
        let rename = DynamicValue.EnumValue(DynamicEnumValue(
            "Rename",
            DynamicEnumPayload.TuplePayload([
                DynamicValue.StringValue("Hi"),
                DynamicValue.BooleanValue(true)
            ])
        ))

        @Assert(toByteArrayDynamic(schema, ping), [0x00u8])
        @Assert(toByteArrayDynamic(schema, speed), [0x01u8, 0x80u8, 0x01u8])
        @Assert(
            toByteArrayDynamic(schema, rename),
            [0x02u8, 0x02u8, 0x48u8, 0x69u8, 0x01u8]
        )
    }

    @TestCase
    public func schemaNodesCanBeDynamicValues(): Unit {
        let described = structSchema("Point", [
            NamedValue("x", int32Schema()),
            NamedValue("y", int32Schema())
        ])
        let bytes = toByteArrayDynamic(
            schemaSchema(),
            DynamicValue.SchemaValue(described)
        )
        match (fromByteArrayDynamic(schemaSchema(), bytes)) {
            case DynamicValue.SchemaValue(decoded) =>
                @Assert(formatSchema(decoded), "struct Point { x: i32, y: i32 }")
            case _ => throw IllegalStateException("Expected schema value")
        }
    }

    @TestCase
    public func cobsFlavorWorksWithDynamicValues(): Unit {
        let frame = serializeDynamicWithFlavor(
            telemetrySchema(),
            telemetryValue(),
            CobsSerializeFlavor(ArraySerializeFlavor())
        )
        let decoded = takeDynamicWithFlavor(
            telemetrySchema(),
            CobsDeserializeFlavor(frame)
        )
        @Assert(decoded[1], [])
        match (decoded[0]) {
            case DynamicValue.StructValue(fields) => @Assert(fields[0].name, "id")
            case _ => throw IllegalStateException("Expected struct")
        }
    }

    @TestCase
    public func uint128MaximumRoundTripsLosslessly(): Unit {
        let maximum = BigInt.parse("340282366920938463463374607431768211455")
        let schema = uint128Schema()
        let bytes = toByteArrayDynamic(schema, DynamicValue.UnsignedValue(maximum))
        match (fromByteArrayDynamic(schema, bytes)) {
            case DynamicValue.UnsignedValue(value) => @Assert(value, maximum)
            case _ => throw IllegalStateException("Expected u128")
        }
    }
}

@Test
public class DynamicErrorTest {
    @TestCase
    public func valueShapeMismatchIsRejected(): Unit {
        @AssertThrows[DynamicException](
            toByteArrayDynamic(uint32Schema(), DynamicValue.StringValue("wrong"))
        )
    }

    @TestCase
    public func truncatedInputMapsToUnexpectedEnd(): Unit {
        try {
            fromByteArrayDynamic(uint32Schema(), [0x80u8])
            throw IllegalStateException("Expected dynamic error")
        } catch (error: DynamicException) {
            match (error.kind) {
                case DynamicErrorKind.UnexpectedEndOfData => ()
                case _ => throw IllegalStateException("Wrong error category")
            }
        }
    }

    @TestCase
    public func trailingBytesAreRejected(): Unit {
        @AssertThrows[DynamicException](
            fromByteArrayDynamic(boolSchema(), [0x01u8, 0x00u8])
        )
    }

    @TestCase
    public func untrustedCollectionLengthsDoNotPreallocateWireCount(): Unit {
        let maliciousLength: Array<UInt8> = [
            0xffu8, 0xffu8, 0xffu8, 0xffu8, 0x0fu8
        ]
        @AssertThrows[DynamicException](
            fromByteArrayDynamic(sequenceSchema(uint8Schema()), maliciousLength)
        )
        @AssertThrows[DynamicException](
            fromByteArrayDynamic(
                mapSchema(uint8Schema(), uint8Schema()),
                maliciousLength
            )
        )
    }
}

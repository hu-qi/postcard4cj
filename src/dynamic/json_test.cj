package postcard4cj.dynamic

import postcard4cj.schema.*
import std.math.numeric.*
import std.unittest.*
import std.unittest.testmacro.*

private func jsonRecordSchema(): NamedType {
    return structSchema("Record", [
        NamedValue("id", uint32Schema()),
        NamedValue("active", boolSchema()),
        NamedValue("note", optionSchema(stringSchema()))
    ])
}

private func jsonCommandSchema(): NamedType {
    return enumSchema("Command", [
        NamedVariant("Ping", DataModelVariant.UnitVariant),
        NamedVariant("SetSpeed", DataModelVariant.NewtypeVariant(uint16Schema())),
        NamedVariant("Rename", DataModelVariant.TupleVariant([
            stringSchema(), boolSchema()
        ]))
    ])
}

@Test
public class DynamicJsonTest {
    @TestCase
    public func structJsonEncodesInSchemaOrder(): Unit {
        let json = JsonValue.ObjectValue([
            JsonField("note", JsonValue.StringValue("ok")),
            JsonField("active", JsonValue.BooleanValue(true)),
            JsonField("id", JsonValue.UnsignedNumber(BigInt(42i64)))
        ])
        @Assert(
            toByteArrayDynamicJson(jsonRecordSchema(), json),
            [0x2au8, 0x01u8, 0x01u8, 0x02u8, 0x6fu8, 0x6bu8]
        )
    }

    @TestCase
    public func nullRepresentsNoneAndValueRepresentsSome(): Unit {
        let schema = optionSchema(stringSchema())
        @Assert(toByteArrayDynamicJson(schema, JsonValue.NullValue), [0x00u8])
        @Assert(
            toByteArrayDynamicJson(schema, JsonValue.StringValue("x")),
            [0x01u8, 0x01u8, 0x78u8]
        )
    }

    @TestCase
    public func tupleArityOneUsesScalarJsonRepresentation(): Unit {
        let schema = tupleSchema([uint16Schema()])
        let json = JsonValue.UnsignedNumber(BigInt(128i64))
        @Assert(toByteArrayDynamicJson(schema, json), [0x80u8, 0x01u8])
        match (fromByteArrayDynamicJson(schema, [0x80u8, 0x01u8])) {
            case JsonValue.UnsignedNumber(value) => @Assert(value, BigInt(128i64))
            case _ => throw IllegalStateException("Expected scalar tuple JSON")
        }
    }

    @TestCase
    public func enumsUseStringOrSingleKeyObject(): Unit {
        let schema = jsonCommandSchema()
        @Assert(
            toByteArrayDynamicJson(schema, JsonValue.StringValue("Ping")),
            [0x00u8]
        )
        let json = JsonValue.ObjectValue([
            JsonField("SetSpeed", JsonValue.UnsignedNumber(BigInt(128i64)))
        ])
        @Assert(
            toByteArrayDynamicJson(schema, json),
            [0x01u8, 0x80u8, 0x01u8]
        )
        match (fromByteArrayDynamicJson(schema, [0x00u8])) {
            case JsonValue.StringValue(name) => @Assert(name, "Ping")
            case _ => throw IllegalStateException("Expected unit variant string")
        }
    }

    @TestCase
    public func bytesUseJsonNumberArray(): Unit {
        let json = JsonValue.ArrayValue([
            JsonValue.UnsignedNumber(BigInt(1i64)),
            JsonValue.UnsignedNumber(BigInt(255i64))
        ])
        @Assert(
            toByteArrayDynamicJson(byteArraySchema(), json),
            [0x02u8, 0x01u8, 0xffu8]
        )
    }

    @TestCase
    public func stringKeyMapUsesJsonObject(): Unit {
        let schema = mapSchema(stringSchema(), uint16Schema())
        let json = JsonValue.ObjectValue([
            JsonField("a", JsonValue.UnsignedNumber(BigInt(1i64))),
            JsonField("b", JsonValue.UnsignedNumber(BigInt(128i64)))
        ])
        @Assert(
            toByteArrayDynamicJson(schema, json),
            [
                0x02u8,
                0x01u8, 0x61u8, 0x01u8,
                0x01u8, 0x62u8, 0x80u8, 0x01u8
            ]
        )
    }

    @TestCase
    public func nonStringMapKeyIsExplicitlyUnsupportedForJson(): Unit {
        let schema = mapSchema(uint8Schema(), stringSchema())
        @AssertThrows[DynamicException](
            jsonToDynamic(schema, JsonValue.ObjectValue([]))
        )
    }

    @TestCase
    public func losslessOptionUnitCannotRoundTripThroughJson(): Unit {
        let schema = optionSchema(unitSchema())
        let json = dynamicToJson(schema, dynamicSome(DynamicValue.UnitValue))
        match (json) {
            case JsonValue.NullValue => ()
            case _ => throw IllegalStateException("Expected upstream-compatible null")
        }
        match (jsonToDynamic(schema, json)) {
            case DynamicValue.OptionValue(option) =>
                match (option.value) {
                    case None => ()
                    case _ => throw IllegalStateException("JSON null maps to None")
                }
            case _ => throw IllegalStateException("Expected Option")
        }
    }
}

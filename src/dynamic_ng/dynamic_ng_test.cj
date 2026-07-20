package postcard4cj.dynamic_ng

import postcard4cj.dynamic.*
import postcard4cj.schema.*
import std.math.numeric.*
import std.unittest.*
import std.unittest.testmacro.*

private func ngDynamicSchema(): NamedType {
    return structSchema("NgPacket", [
        NamedValue("id", uint32Schema()),
        NamedValue("enabled", boolSchema())
    ])
}

private func ngDynamicValue(): DynamicValue {
    return DynamicValue.StructValue([
        DynamicField("id", DynamicValue.UnsignedValue(BigInt(300i64))),
        DynamicField("enabled", DynamicValue.BooleanValue(true))
    ])
}

@Test
public class DynamicNgCompatibilityTest {
    @TestCase
    public func losslessApiUsesIdenticalWireBytes(): Unit {
        let expected: Array<UInt8> = [0xacu8, 0x02u8, 0x01u8]
        @Assert(toByteArrayDynamicNg(ngDynamicSchema(), ngDynamicValue()), expected)
        match (fromByteArrayDynamicNg(ngDynamicSchema(), expected)) {
            case DynamicValue.StructValue(fields) =>
                @Assert(fields.size, 2)
                @Assert(fields[1].name, "enabled")
            case _ => throw IllegalStateException("Expected dynamic struct")
        }
    }

    @TestCase
    public func jsonApiUsesUpstreamCompatibleShape(): Unit {
        let json = JsonValue.ObjectValue([
            JsonField("id", JsonValue.UnsignedNumber(BigInt(300i64))),
            JsonField("enabled", JsonValue.BooleanValue(true))
        ])
        let bytes = toByteArrayDynamicJsonNg(ngDynamicSchema(), json)
        @Assert(bytes, [0xacu8, 0x02u8, 0x01u8])
        match (fromByteArrayDynamicJsonNg(ngDynamicSchema(), bytes)) {
            case JsonValue.ObjectValue(fields) =>
                @Assert(fields.size, 2)
                @Assert(fields[0].name, "id")
            case _ => throw IllegalStateException("Expected JSON object")
        }
    }

    @TestCase
    public func takeApiPreservesRemainder(): Unit {
        let decoded = takeFromByteArrayDynamicNg(
            ngDynamicSchema(),
            [0xacu8, 0x02u8, 0x01u8, 0xffu8]
        )
        @Assert(decoded[1], [0xffu8])
    }
}

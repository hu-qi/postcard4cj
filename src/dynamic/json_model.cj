package postcard4cj.dynamic

import std.math.numeric.*

public class JsonField {
    public let name: String
    public let value: JsonValue

    public init(name: String, value: JsonValue) {
        this.name = name
        this.value = value
    }
}

/** Cangjie counterpart of serde_json::Value used by postcard-dyn. */
public enum JsonValue {
    | NullValue
    | BooleanValue(Bool)
    | SignedNumber(BigInt)
    | UnsignedNumber(BigInt)
    | FloatNumber(Float64)
    | StringValue(String)
    | ArrayValue(Array<JsonValue>)
    | ObjectValue(Array<JsonField>)
}

func jsonMismatch(message: String): Nothing {
    throw DynamicException(DynamicErrorKind.SchemaMismatch, message)
}

func jsonUnsupported(message: String): Nothing {
    throw DynamicException(DynamicErrorKind.ShouldSupportButDont, message)
}

func runeString(value: Rune): String {
    let length = Rune.utf8Size(value)
    let buffer = Array<UInt8>(length, repeat: 0u8)
    Rune.intoUtf8Array(value, buffer, 0)
    return String.fromUtf8(buffer)
}

func findJsonField(fields: Array<JsonField>, name: String): JsonValue {
    for (field in fields) {
        if (field.name == name) {
            return field.value
        }
    }
    return jsonMismatch("Missing JSON field '${name}'")
}

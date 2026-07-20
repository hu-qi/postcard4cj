package postcard4cj.dynamic

import postcard4cj.schema.*
import std.collection.*
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

private func jsonMismatch(message: String): Nothing {
    throw DynamicException(DynamicErrorKind.SchemaMismatch, message)
}

private func jsonUnsupported(message: String): Nothing {
    throw DynamicException(DynamicErrorKind.ShouldSupportButDont, message)
}

private func runeString(value: Rune): String {
    let length = Rune.utf8Size(value)
    let buffer = Array<UInt8>(length, repeat: 0u8)
    Rune.intoUtf8Array(value, buffer, 0)
    return String.fromUtf8(buffer)
}

private func dynamicArrayToJson(
    schemas: Array<NamedType>,
    values: Array<DynamicValue>
): JsonValue {
    if (schemas.size != values.size) {
        return jsonMismatch("Dynamic tuple arity does not match schema")
    }
    if (values.size == 0) {
        return JsonValue.NullValue
    }
    if (values.size == 1) {
        return dynamicToJson(schemas[0], values[0])
    }
    return JsonValue.ArrayValue(Array<JsonValue>(values.size, {index: Int64 =>
        dynamicToJson(schemas[index], values[index])
    }))
}

private func dynamicFieldsToJson(
    schemas: Array<NamedValue>,
    values: Array<DynamicField>
): JsonValue {
    if (schemas.size != values.size) {
        return jsonMismatch("Dynamic struct field count does not match schema")
    }
    let output = Array<JsonField>(schemas.size, {index: Int64 =>
        let expected = schemas[index]
        var found: Option<DynamicValue> = None
        for (field in values) {
            if (field.name == expected.name) {
                found = Some(field.value)
                break
            }
        }
        match (found) {
            case Some(value) => JsonField(
                expected.name,
                dynamicToJson(expected.ty, value)
            )
            case None => jsonMismatch("Missing dynamic field '${expected.name}'")
        }
    })
    return JsonValue.ObjectValue(output)
}

/** Convert a lossless DynamicValue to the upstream serde_json-compatible shape. */
public func dynamicToJson(schema: NamedType, value: DynamicValue): JsonValue {
    return match (schema.ty) {
        case DataModelType.Boolean =>
            match (value) {
                case DynamicValue.BooleanValue(inner) => JsonValue.BooleanValue(inner)
                case _ => jsonMismatch("Expected Bool")
            }
        case DataModelType.I8 | DataModelType.I16 | DataModelType.I32 |
            DataModelType.I64 | DataModelType.I128 | DataModelType.Isize =>
            match (value) {
                case DynamicValue.SignedValue(inner) => JsonValue.SignedNumber(inner)
                case _ => jsonMismatch("Expected signed number")
            }
        case DataModelType.U8 | DataModelType.U16 | DataModelType.U32 |
            DataModelType.U64 | DataModelType.U128 | DataModelType.Usize =>
            match (value) {
                case DynamicValue.UnsignedValue(inner) => JsonValue.UnsignedNumber(inner)
                case _ => jsonMismatch("Expected unsigned number")
            }
        case DataModelType.F32 | DataModelType.F64 =>
            match (value) {
                case DynamicValue.FloatValue(inner) => JsonValue.FloatNumber(inner)
                case _ => jsonMismatch("Expected floating number")
            }
        case DataModelType.Char =>
            match (value) {
                case DynamicValue.RuneValue(inner) => JsonValue.StringValue(runeString(inner))
                case _ => jsonMismatch("Expected Rune")
            }
        case DataModelType.StringValue =>
            match (value) {
                case DynamicValue.StringValue(inner) => JsonValue.StringValue(inner)
                case _ => jsonMismatch("Expected String")
            }
        case DataModelType.ByteArray =>
            match (value) {
                case DynamicValue.BytesValue(inner) =>
                    JsonValue.ArrayValue(Array<JsonValue>(inner.size, {index: Int64 =>
                        JsonValue.UnsignedNumber(BigInt(inner[index]))
                    }))
                case _ => jsonMismatch("Expected bytes")
            }
        case DataModelType.Option(innerSchema) =>
            match (value) {
                case DynamicValue.OptionValue(option) =>
                    match (option.value) {
                        case Some(inner) => dynamicToJson(innerSchema, inner)
                        case None => JsonValue.NullValue
                    }
                case _ => jsonMismatch("Expected Option")
            }
        case DataModelType.UnitValue | DataModelType.UnitStruct =>
            match (value) {
                case DynamicValue.UnitValue => JsonValue.NullValue
                case _ => jsonMismatch("Expected Unit")
            }
        case DataModelType.NewtypeStruct(innerSchema) =>
            dynamicToJson(innerSchema, value)
        case DataModelType.Seq(innerSchema) =>
            match (value) {
                case DynamicValue.SequenceValue(values) =>
                    JsonValue.ArrayValue(Array<JsonValue>(values.size, {index: Int64 =>
                        dynamicToJson(innerSchema, values[index])
                    }))
                case _ => jsonMismatch("Expected sequence")
            }
        case DataModelType.Tuple(schemas) | DataModelType.TupleStruct(schemas) =>
            match (value) {
                case DynamicValue.TupleValue(values) => dynamicArrayToJson(schemas, values)
                case _ => jsonMismatch("Expected tuple")
            }
        case DataModelType.Map(keySchema, valueSchema) =>
            match (keySchema.ty) {
                case DataModelType.StringValue => ()
                case _ => jsonUnsupported("JSON objects require String map keys")
            }
            match (value) {
                case DynamicValue.MapValue(entries) =>
                    JsonValue.ObjectValue(Array<JsonField>(entries.size, {index: Int64 =>
                        let key = match (entries[index].key) {
                            case DynamicValue.StringValue(inner) => inner
                            case _ => jsonMismatch("Expected String map key")
                        }
                        JsonField(key, dynamicToJson(valueSchema, entries[index].value))
                    }))
                case _ => jsonMismatch("Expected map")
            }
        case DataModelType.Struct(fieldSchemas) =>
            match (value) {
                case DynamicValue.StructValue(fields) =>
                    dynamicFieldsToJson(fieldSchemas, fields)
                case _ => jsonMismatch("Expected struct")
            }
        case DataModelType.Enum(variantSchemas) =>
            match (value) {
                case DynamicValue.EnumValue(enumValue) =>
                    var selected: Option<NamedVariant> = None
                    for (variant in variantSchemas) {
                        if (variant.name == enumValue.name) {
                            selected = Some(variant)
                            break
                        }
                    }
                    let variant = match (selected) {
                        case Some(inner) => inner
                        case None => jsonMismatch("Unknown enum variant")
                    }
                    match (variant.ty) {
                        case DataModelVariant.UnitVariant =>
                            match (enumValue.payload) {
                                case DynamicEnumPayload.UnitPayload =>
                                    JsonValue.StringValue(enumValue.name)
                                case _ => jsonMismatch("Expected unit enum payload")
                            }
                        case DataModelVariant.NewtypeVariant(innerSchema) =>
                            match (enumValue.payload) {
                                case DynamicEnumPayload.NewtypePayload(inner) =>
                                    JsonValue.ObjectValue([
                                        JsonField(enumValue.name, dynamicToJson(innerSchema, inner))
                                    ])
                                case _ => jsonMismatch("Expected newtype enum payload")
                            }
                        case DataModelVariant.TupleVariant(schemas) =>
                            match (enumValue.payload) {
                                case DynamicEnumPayload.TuplePayload(values) =>
                                    JsonValue.ObjectValue([
                                        JsonField(enumValue.name, dynamicArrayToJson(schemas, values))
                                    ])
                                case _ => jsonMismatch("Expected tuple enum payload")
                            }
                        case DataModelVariant.StructVariant(schemas) =>
                            match (enumValue.payload) {
                                case DynamicEnumPayload.StructPayload(fields) =>
                                    JsonValue.ObjectValue([
                                        JsonField(enumValue.name, dynamicFieldsToJson(schemas, fields))
                                    ])
                                case _ => jsonMismatch("Expected struct enum payload")
                            }
                    }
                case _ => jsonMismatch("Expected enum")
            }
        case DataModelType.Schema =>
            jsonUnsupported("Schema values do not have an upstream JSON representation")
    }
}

private func findJsonField(fields: Array<JsonField>, name: String): JsonValue {
    for (field in fields) {
        if (field.name == name) {
            return field.value
        }
    }
    return jsonMismatch("Missing JSON field '${name}'")
}

private func jsonTupleToDynamic(
    schemas: Array<NamedType>,
    value: JsonValue
): DynamicValue {
    if (schemas.size == 0) {
        return match (value) {
            case JsonValue.NullValue => DynamicValue.TupleValue([])
            case _ => jsonMismatch("Expected null for empty tuple")
        }
    }
    if (schemas.size == 1) {
        return DynamicValue.TupleValue([jsonToDynamic(schemas[0], value)])
    }
    return match (value) {
        case JsonValue.ArrayValue(values) =>
            if (values.size != schemas.size) {
                jsonMismatch("JSON tuple arity does not match schema")
            }
            DynamicValue.TupleValue(Array<DynamicValue>(values.size, {index: Int64 =>
                jsonToDynamic(schemas[index], values[index])
            }))
        case _ => jsonMismatch("Expected JSON array for tuple")
    }
}

/** Convert a serde_json-compatible shape into a lossless DynamicValue using Schema. */
public func jsonToDynamic(schema: NamedType, value: JsonValue): DynamicValue {
    return match (schema.ty) {
        case DataModelType.Boolean =>
            match (value) {
                case JsonValue.BooleanValue(inner) => DynamicValue.BooleanValue(inner)
                case _ => jsonMismatch("Expected JSON bool")
            }
        case DataModelType.I8 | DataModelType.I16 | DataModelType.I32 |
            DataModelType.I64 | DataModelType.I128 | DataModelType.Isize =>
            match (value) {
                case JsonValue.SignedNumber(inner) => DynamicValue.SignedValue(inner)
                case _ => jsonMismatch("Expected JSON signed number")
            }
        case DataModelType.U8 | DataModelType.U16 | DataModelType.U32 |
            DataModelType.U64 | DataModelType.U128 | DataModelType.Usize =>
            match (value) {
                case JsonValue.UnsignedNumber(inner) => DynamicValue.UnsignedValue(inner)
                case _ => jsonMismatch("Expected JSON unsigned number")
            }
        case DataModelType.F32 | DataModelType.F64 =>
            match (value) {
                case JsonValue.FloatNumber(inner) => DynamicValue.FloatValue(inner)
                case _ => jsonMismatch("Expected JSON float")
            }
        case DataModelType.Char =>
            match (value) {
                case JsonValue.StringValue(inner) =>
                    let bytes = inner.toArray()
                    let decoded = Rune.fromUtf8(bytes, 0)
                    if (decoded[1] != bytes.size) {
                        jsonMismatch("JSON char must contain one scalar value")
                    }
                    DynamicValue.RuneValue(decoded[0])
                case _ => jsonMismatch("Expected JSON string for char")
            }
        case DataModelType.StringValue =>
            match (value) {
                case JsonValue.StringValue(inner) => DynamicValue.StringValue(inner)
                case _ => jsonMismatch("Expected JSON string")
            }
        case DataModelType.ByteArray =>
            match (value) {
                case JsonValue.ArrayValue(values) =>
                    DynamicValue.BytesValue(Array<UInt8>(values.size, {index: Int64 =>
                        match (values[index]) {
                            case JsonValue.UnsignedNumber(inner) => inner.toUInt8()
                            case _ => jsonMismatch("Byte array requires unsigned JSON numbers")
                        }
                    }))
                case _ => jsonMismatch("Expected JSON array for bytes")
            }
        case DataModelType.Option(innerSchema) =>
            match (value) {
                case JsonValue.NullValue => dynamicNone()
                case _ => dynamicSome(jsonToDynamic(innerSchema, value))
            }
        case DataModelType.UnitValue | DataModelType.UnitStruct =>
            match (value) {
                case JsonValue.NullValue => DynamicValue.UnitValue
                case _ => jsonMismatch("Expected JSON null for Unit")
            }
        case DataModelType.NewtypeStruct(innerSchema) => jsonToDynamic(innerSchema, value)
        case DataModelType.Seq(innerSchema) =>
            match (value) {
                case JsonValue.ArrayValue(values) =>
                    DynamicValue.SequenceValue(Array<DynamicValue>(values.size, {index: Int64 =>
                        jsonToDynamic(innerSchema, values[index])
                    }))
                case _ => jsonMismatch("Expected JSON array for sequence")
            }
        case DataModelType.Tuple(schemas) | DataModelType.TupleStruct(schemas) =>
            jsonTupleToDynamic(schemas, value)
        case DataModelType.Map(keySchema, valueSchema) =>
            match (keySchema.ty) {
                case DataModelType.StringValue => ()
                case _ => jsonUnsupported("JSON objects require String map keys")
            }
            match (value) {
                case JsonValue.ObjectValue(fields) =>
                    DynamicValue.MapValue(Array<DynamicEntry>(fields.size, {index: Int64 =>
                        DynamicEntry(
                            DynamicValue.StringValue(fields[index].name),
                            jsonToDynamic(valueSchema, fields[index].value)
                        )
                    }))
                case _ => jsonMismatch("Expected JSON object for map")
            }
        case DataModelType.Struct(fieldSchemas) =>
            match (value) {
                case JsonValue.ObjectValue(fields) =>
                    if (fields.size != fieldSchemas.size) {
                        jsonMismatch("JSON struct field count mismatch")
                    }
                    DynamicValue.StructValue(Array<DynamicField>(fieldSchemas.size, {index: Int64 =>
                        let expected = fieldSchemas[index]
                        DynamicField(
                            expected.name,
                            jsonToDynamic(expected.ty, findJsonField(fields, expected.name))
                        )
                    }))
                case _ => jsonMismatch("Expected JSON object for struct")
            }
        case DataModelType.Enum(variantSchemas) =>
            match (value) {
                case JsonValue.StringValue(name) =>
                    var valid = false
                    for (variant in variantSchemas) {
                        if (variant.name == name) {
                            match (variant.ty) {
                                case DataModelVariant.UnitVariant => valid = true
                                case _ => ()
                            }
                        }
                    }
                    if (!valid) { jsonMismatch("Unknown JSON unit enum variant") }
                    DynamicValue.EnumValue(DynamicEnumValue(
                        name,
                        DynamicEnumPayload.UnitPayload
                    ))
                case JsonValue.ObjectValue(fields) =>
                    if (fields.size != 1) {
                        jsonMismatch("JSON enum object must contain one variant")
                    }
                    let name = fields[0].name
                    var selected: Option<NamedVariant> = None
                    for (variant in variantSchemas) {
                        if (variant.name == name) {
                            selected = Some(variant)
                            break
                        }
                    }
                    let variant = match (selected) {
                        case Some(inner) => inner
                        case None => jsonMismatch("Unknown JSON enum variant")
                    }
                    let payload = match (variant.ty) {
                        case DataModelVariant.UnitVariant => DynamicEnumPayload.UnitPayload
                        case DataModelVariant.NewtypeVariant(innerSchema) =>
                            DynamicEnumPayload.NewtypePayload(
                                jsonToDynamic(innerSchema, fields[0].value)
                            )
                        case DataModelVariant.TupleVariant(schemas) =>
                            match (jsonTupleToDynamic(schemas, fields[0].value)) {
                                case DynamicValue.TupleValue(values) =>
                                    DynamicEnumPayload.TuplePayload(values)
                                case _ => jsonMismatch("Expected tuple enum JSON payload")
                            }
                        case DataModelVariant.StructVariant(schemas) =>
                            match (jsonToDynamic(
                                NamedType(name, DataModelType.Struct(schemas)),
                                fields[0].value
                            )) {
                                case DynamicValue.StructValue(values) =>
                                    DynamicEnumPayload.StructPayload(values)
                                case _ => jsonMismatch("Expected struct enum JSON payload")
                            }
                    }
                    DynamicValue.EnumValue(DynamicEnumValue(name, payload))
                case _ => jsonMismatch("Expected JSON string or object for enum")
            }
        case DataModelType.Schema =>
            jsonUnsupported("Schema values do not have an upstream JSON representation")
    }
}

public func toByteArrayDynamicJson(schema: NamedType, value: JsonValue): Array<UInt8> {
    return toByteArrayDynamic(schema, jsonToDynamic(schema, value))
}

public func fromByteArrayDynamicJson(schema: NamedType, input: Array<UInt8>): JsonValue {
    return dynamicToJson(schema, fromByteArrayDynamic(schema, input))
}

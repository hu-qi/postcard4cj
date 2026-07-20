package postcard4cj.dynamic

import postcard4cj.schema.*
import std.math.numeric.*

func jsonTupleToDynamic(
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
        case DataModelType.Tuple(schemas) => jsonTupleToDynamic(schemas, value)
        case DataModelType.TupleStruct(schemas) => jsonTupleToDynamic(schemas, value)
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
                    if (!valid) {
                        jsonMismatch("Unknown JSON unit enum variant")
                    }
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

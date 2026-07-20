package postcard4cj.dynamic

import postcard4cj.schema.*
import std.math.numeric.*

func dynamicArrayToJson(
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

func dynamicFieldsToJson(
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
        case DataModelType.Tuple(schemas) =>
            match (value) {
                case DynamicValue.TupleValue(values) => dynamicArrayToJson(schemas, values)
                case _ => jsonMismatch("Expected tuple")
            }
        case DataModelType.TupleStruct(schemas) =>
            match (value) {
                case DynamicValue.TupleValue(values) => dynamicArrayToJson(schemas, values)
                case _ => jsonMismatch("Expected tuple struct")
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

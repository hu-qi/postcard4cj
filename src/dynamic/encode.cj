package postcard4cj.dynamic

import postcard4cj.flavors.*
import postcard4cj.schema.*
import postcard4cj.serde_model.*
import std.math.numeric.*

private func mismatch(message: String): Nothing {
    throw DynamicException(DynamicErrorKind.SchemaMismatch, message)
}

private func signedNumber(value: DynamicValue): BigInt {
    return match (value) {
        case DynamicValue.SignedValue(number) => number
        case _ => mismatch("Expected a signed dynamic number")
    }
}

private func unsignedNumber(value: DynamicValue): BigInt {
    return match (value) {
        case DynamicValue.UnsignedValue(number) => number
        case _ => mismatch("Expected an unsigned dynamic number")
    }
}

private func floatingNumber(value: DynamicValue): Float64 {
    return match (value) {
        case DynamicValue.FloatValue(number) => number
        case _ => mismatch("Expected a floating-point dynamic number")
    }
}

private func findField(fields: Array<DynamicField>, name: String): DynamicValue {
    for (field in fields) {
        if (field.name == name) {
            return field.value
        }
    }
    return mismatch("Missing dynamic field '${name}'")
}

private func findVariant(
    variants: Array<NamedVariant>,
    name: String
): (UInt32, NamedVariant) {
    var index = 0i64
    while (index < variants.size) {
        if (variants[index].name == name) {
            return (UInt32(index), variants[index])
        }
        index++
    }
    return mismatch("Unknown dynamic enum variant '${name}'")
}

private func encodeNamedTypes(
    serializer: Serializer,
    schemas: Array<NamedType>,
    values: Array<DynamicValue>
): Unit {
    if (schemas.size != values.size) {
        mismatch("Dynamic tuple arity does not match its schema")
    }
    var index = 0i64
    while (index < schemas.size) {
        encodeValue(serializer, schemas[index], values[index])
        index++
    }
}

private func encodeValue(
    serializer: Serializer,
    schema: NamedType,
    value: DynamicValue
): Unit {
    match (schema.ty) {
        case DataModelType.Boolean =>
            match (value) {
                case DynamicValue.BooleanValue(inner) => serializer.serializeBool(inner)
                case _ => mismatch("Expected Bool for schema '${schema.name}'")
            }
        case DataModelType.I8 => serializer.serializeInt8(signedNumber(value).toInt8())
        case DataModelType.I16 => serializer.serializeInt16(signedNumber(value).toInt16())
        case DataModelType.I32 => serializer.serializeInt32(signedNumber(value).toInt32())
        case DataModelType.I64 => serializer.serializeInt64(signedNumber(value).toInt64())
        case DataModelType.I128 => serializer.serializeInt128(signedNumber(value))
        case DataModelType.Isize => serializer.serializePlatformInt(signedNumber(value).toInt64())
        case DataModelType.U8 => serializer.serializeUInt8(unsignedNumber(value).toUInt8())
        case DataModelType.U16 => serializer.serializeUInt16(unsignedNumber(value).toUInt16())
        case DataModelType.U32 => serializer.serializeUInt32(unsignedNumber(value).toUInt32())
        case DataModelType.U64 => serializer.serializeUInt64(unsignedNumber(value).toUInt64())
        case DataModelType.U128 => serializer.serializeUInt128(unsignedNumber(value))
        case DataModelType.Usize => serializer.serializePlatformUInt(unsignedNumber(value).toUInt64())
        case DataModelType.F32 => serializer.serializeFloat32(Float32(floatingNumber(value)))
        case DataModelType.F64 => serializer.serializeFloat64(floatingNumber(value))
        case DataModelType.Char =>
            match (value) {
                case DynamicValue.RuneValue(inner) => serializer.serializeRune(inner)
                case _ => mismatch("Expected Rune for schema '${schema.name}'")
            }
        case DataModelType.StringValue =>
            match (value) {
                case DynamicValue.StringValue(inner) => serializer.serializeString(inner)
                case _ => mismatch("Expected String for schema '${schema.name}'")
            }
        case DataModelType.ByteArray =>
            match (value) {
                case DynamicValue.BytesValue(inner) => serializer.serializeBytes(inner)
                case _ => mismatch("Expected byte array for schema '${schema.name}'")
            }
        case DataModelType.Option(innerSchema) =>
            match (value) {
                case DynamicValue.OptionValue(option) =>
                    match (option.value) {
                        case Some(inner) =>
                            serializer.serializeSome<DynamicValue>(
                                inner,
                                {item: DynamicValue => encodeValue(serializer, innerSchema, item)}
                            )
                        case None => serializer.serializeNone()
                    }
                case _ => mismatch("Expected Option for schema '${schema.name}'")
            }
        case DataModelType.UnitValue =>
            match (value) {
                case DynamicValue.UnitValue => serializer.serializeUnit()
                case _ => mismatch("Expected Unit for schema '${schema.name}'")
            }
        case DataModelType.UnitStruct =>
            match (value) {
                case DynamicValue.UnitValue => serializer.beginUnitStruct(schema.name)
                case _ => mismatch("Expected unit struct for schema '${schema.name}'")
            }
        case DataModelType.NewtypeStruct(innerSchema) =>
            serializer.beginNewtypeStruct(schema.name)
            encodeValue(serializer, innerSchema, value)
        case DataModelType.Seq(innerSchema) =>
            match (value) {
                case DynamicValue.SequenceValue(values) =>
                    serializer.beginSequence(Some(values.size))
                    for (item in values) {
                        encodeValue(serializer, innerSchema, item)
                    }
                case _ => mismatch("Expected sequence for schema '${schema.name}'")
            }
        case DataModelType.Tuple(elementSchemas) =>
            match (value) {
                case DynamicValue.TupleValue(values) =>
                    serializer.beginTuple(elementSchemas.size)
                    encodeNamedTypes(serializer, elementSchemas, values)
                case _ => mismatch("Expected tuple for schema '${schema.name}'")
            }
        case DataModelType.TupleStruct(elementSchemas) =>
            match (value) {
                case DynamicValue.TupleValue(values) =>
                    serializer.beginTupleStruct(schema.name, elementSchemas.size)
                    encodeNamedTypes(serializer, elementSchemas, values)
                case _ => mismatch("Expected tuple struct for schema '${schema.name}'")
            }
        case DataModelType.Map(keySchema, valueSchema) =>
            match (value) {
                case DynamicValue.MapValue(entries) =>
                    serializer.beginMap(Some(entries.size))
                    for (entry in entries) {
                        encodeValue(serializer, keySchema, entry.key)
                        encodeValue(serializer, valueSchema, entry.value)
                    }
                case _ => mismatch("Expected map for schema '${schema.name}'")
            }
        case DataModelType.Struct(fieldSchemas) =>
            match (value) {
                case DynamicValue.StructValue(fields) =>
                    if (fields.size != fieldSchemas.size) {
                        mismatch("Dynamic struct field count does not match '${schema.name}'")
                    }
                    serializer.beginStruct(schema.name, fieldSchemas.size)
                    for (fieldSchema in fieldSchemas) {
                        encodeValue(
                            serializer,
                            fieldSchema.ty,
                            findField(fields, fieldSchema.name)
                        )
                    }
                    serializer.endContainer()
                case _ => mismatch("Expected struct for schema '${schema.name}'")
            }
        case DataModelType.Enum(variantSchemas) =>
            match (value) {
                case DynamicValue.EnumValue(enumValue) =>
                    let selected = findVariant(variantSchemas, enumValue.name)
                    match (selected[1].ty) {
                        case DataModelVariant.UnitVariant =>
                            match (enumValue.payload) {
                                case DynamicEnumPayload.UnitPayload =>
                                    serializer.beginUnitVariant(selected[0])
                                case _ => mismatch("Expected unit enum payload")
                            }
                        case DataModelVariant.NewtypeVariant(innerSchema) =>
                            match (enumValue.payload) {
                                case DynamicEnumPayload.NewtypePayload(inner) =>
                                    serializer.beginNewtypeVariant(selected[0])
                                    encodeValue(serializer, innerSchema, inner)
                                case _ => mismatch("Expected newtype enum payload")
                            }
                        case DataModelVariant.TupleVariant(elementSchemas) =>
                            match (enumValue.payload) {
                                case DynamicEnumPayload.TuplePayload(values) =>
                                    serializer.beginTupleVariant(selected[0], elementSchemas.size)
                                    encodeNamedTypes(serializer, elementSchemas, values)
                                case _ => mismatch("Expected tuple enum payload")
                            }
                        case DataModelVariant.StructVariant(fieldSchemas) =>
                            match (enumValue.payload) {
                                case DynamicEnumPayload.StructPayload(fields) =>
                                    if (fields.size != fieldSchemas.size) {
                                        mismatch("Dynamic enum struct field count mismatch")
                                    }
                                    serializer.beginStructVariant(selected[0], fieldSchemas.size)
                                    for (fieldSchema in fieldSchemas) {
                                        encodeValue(
                                            serializer,
                                            fieldSchema.ty,
                                            findField(fields, fieldSchema.name)
                                        )
                                    }
                                case _ => mismatch("Expected struct enum payload")
                            }
                    }
                case _ => mismatch("Expected enum for schema '${schema.name}'")
            }
        case DataModelType.Schema =>
            match (value) {
                case DynamicValue.SchemaValue(inner) => inner.serialize(serializer)
                case _ => mismatch("Expected Schema value")
            }
    }
}

/** Serialize a dynamic value using an explicit Flavor pipeline. */
public func serializeDynamicWithFlavor(
    schema: NamedType,
    value: DynamicValue,
    flavor: SerializeFlavor
): Array<UInt8> {
    let serializer = Serializer(flavor)
    try {
        encodeValue(serializer, schema, value)
        return serializer.finalize()
    } catch (error: DynamicException) {
        throw error
    } catch (_: Exception) {
        throw DynamicException(
            DynamicErrorKind.SchemaMismatch,
            "Dynamic value is outside the range required by its schema"
        )
    }
}

public func toByteArrayDynamic(schema: NamedType, value: DynamicValue): Array<UInt8> {
    return serializeDynamicWithFlavor(schema, value, ArraySerializeFlavor())
}

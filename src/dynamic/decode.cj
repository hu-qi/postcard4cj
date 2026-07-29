package postcard4cj.dynamic

import postcard4cj.core.*
import postcard4cj.flavors.*
import postcard4cj.schema.*
import postcard4cj.serde_model.*
import std.collection.*
import std.math.numeric.*

private func unsignedBig(value: UInt64): BigInt {
    return BigInt.parse(value.toString())
}

private func decodeFixedTuple(
    deserializer: Deserializer,
    schemas: Array<NamedType>
): Array<DynamicValue> {
    let output = ArrayList<DynamicValue>(schemas.size)
    for (schema in schemas) {
        output.add(decodeValue(deserializer, schema))
    }
    return output.toArray()
}

private func decodeValue(deserializer: Deserializer, schema: NamedType): DynamicValue {
    return match (schema.ty) {
        case DataModelType.Boolean =>
            DynamicValue.BooleanValue(deserializer.deserializeBool())
        case DataModelType.I8 =>
            DynamicValue.SignedValue(BigInt(Int64(deserializer.deserializeInt8())))
        case DataModelType.I16 =>
            DynamicValue.SignedValue(BigInt(Int64(deserializer.deserializeInt16())))
        case DataModelType.I32 =>
            DynamicValue.SignedValue(BigInt(Int64(deserializer.deserializeInt32())))
        case DataModelType.I64 =>
            DynamicValue.SignedValue(BigInt(deserializer.deserializeInt64()))
        case DataModelType.I128 =>
            DynamicValue.SignedValue(deserializer.deserializeInt128())
        case DataModelType.Isize =>
            DynamicValue.SignedValue(BigInt(deserializer.deserializePlatformInt()))
        case DataModelType.U8 =>
            DynamicValue.UnsignedValue(BigInt(deserializer.deserializeUInt8()))
        case DataModelType.U16 =>
            DynamicValue.UnsignedValue(BigInt(deserializer.deserializeUInt16()))
        case DataModelType.U32 =>
            DynamicValue.UnsignedValue(BigInt(deserializer.deserializeUInt32()))
        case DataModelType.U64 =>
            DynamicValue.UnsignedValue(unsignedBig(deserializer.deserializeUInt64()))
        case DataModelType.U128 =>
            DynamicValue.UnsignedValue(deserializer.deserializeUInt128())
        case DataModelType.Usize =>
            DynamicValue.UnsignedValue(unsignedBig(deserializer.deserializePlatformUInt()))
        case DataModelType.F32 =>
            DynamicValue.FloatValue(Float64(deserializer.deserializeFloat32()))
        case DataModelType.F64 =>
            DynamicValue.FloatValue(deserializer.deserializeFloat64())
        case DataModelType.Char =>
            DynamicValue.RuneValue(deserializer.deserializeRune())
        case DataModelType.StringValue =>
            DynamicValue.StringValue(deserializer.deserializeString())
        case DataModelType.ByteArray =>
            DynamicValue.BytesValue(deserializer.deserializeBytes())
        case DataModelType.Option(innerSchema) =>
            DynamicValue.OptionValue(DynamicOption(
                deserializer.deserializeOption<DynamicValue>(
                    {=> decodeValue(deserializer, innerSchema)}
                )
            ))
        case DataModelType.UnitValue =>
            deserializer.deserializeUnit()
            DynamicValue.UnitValue
        case DataModelType.UnitStruct =>
            deserializer.beginUnitStruct(schema.name)
            DynamicValue.UnitValue
        case DataModelType.NewtypeStruct(innerSchema) =>
            deserializer.beginNewtypeStruct(schema.name)
            decodeValue(deserializer, innerSchema)
        case DataModelType.Seq(innerSchema) =>
            let length = deserializer.beginSequence()
            let initialCapacity = match (deserializer.sizeHint()) {
                case Some(remaining) => if (length > remaining) { remaining } else { length }
                case None => 0
            }
            let output = ArrayList<DynamicValue>(initialCapacity)
            var index = 0i64
            while (index < length) {
                output.add(decodeValue(deserializer, innerSchema))
                index++
            }
            DynamicValue.SequenceValue(output.toArray())
        case DataModelType.Tuple(elementSchemas) =>
            deserializer.beginTuple(elementSchemas.size)
            DynamicValue.TupleValue(decodeFixedTuple(deserializer, elementSchemas))
        case DataModelType.TupleStruct(elementSchemas) =>
            deserializer.beginTupleStruct(schema.name, elementSchemas.size)
            DynamicValue.TupleValue(decodeFixedTuple(deserializer, elementSchemas))
        case DataModelType.Map(keySchema, valueSchema) =>
            let length = deserializer.beginMap()
            let initialCapacity = match (deserializer.sizeHint()) {
                case Some(remaining) => if (length > remaining) { remaining } else { length }
                case None => 0
            }
            let output = ArrayList<DynamicEntry>(initialCapacity)
            var index = 0i64
            while (index < length) {
                output.add(DynamicEntry(
                    decodeValue(deserializer, keySchema),
                    decodeValue(deserializer, valueSchema)
                ))
                index++
            }
            DynamicValue.MapValue(output.toArray())
        case DataModelType.Struct(fieldSchemas) =>
            deserializer.beginStruct(schema.name, fieldSchemas.size)
            let output = ArrayList<DynamicField>(fieldSchemas.size)
            for (fieldSchema in fieldSchemas) {
                output.add(DynamicField(
                    fieldSchema.name,
                    decodeValue(deserializer, fieldSchema.ty)
                ))
            }
            deserializer.endContainer()
            DynamicValue.StructValue(output.toArray())
        case DataModelType.Enum(variantSchemas) =>
            let index = Int64(deserializer.deserializeVariantIndex())
            if (index < 0 || index >= variantSchemas.size) {
                throw DynamicException(
                    DynamicErrorKind.SchemaMismatch,
                    "Enum discriminant exceeds the supplied schema"
                )
            }
            let variant = variantSchemas[index]
            let payload = match (variant.ty) {
                case DataModelVariant.UnitVariant => DynamicEnumPayload.UnitPayload
                case DataModelVariant.NewtypeVariant(innerSchema) =>
                    DynamicEnumPayload.NewtypePayload(
                        decodeValue(deserializer, innerSchema)
                    )
                case DataModelVariant.TupleVariant(elementSchemas) =>
                    DynamicEnumPayload.TuplePayload(
                        decodeFixedTuple(deserializer, elementSchemas)
                    )
                case DataModelVariant.StructVariant(fieldSchemas) =>
                    let fields = ArrayList<DynamicField>(fieldSchemas.size)
                    for (fieldSchema in fieldSchemas) {
                        fields.add(DynamicField(
                            fieldSchema.name,
                            decodeValue(deserializer, fieldSchema.ty)
                        ))
                    }
                    DynamicEnumPayload.StructPayload(fields.toArray())
            }
            DynamicValue.EnumValue(DynamicEnumValue(variant.name, payload))
        case DataModelType.Schema =>
            DynamicValue.SchemaValue(NamedType.deserialize(deserializer))
    }
}

private func mapPostcardError(error: PostcardException): DynamicException {
    return match (error.kind) {
        case PostcardErrorKind.DeserializeUnexpectedEnd =>
            DynamicException(
                DynamicErrorKind.UnexpectedEndOfData,
                "Unexpected end of dynamic Postcard input"
            )
        case _ => DynamicException(
            DynamicErrorKind.SchemaMismatch,
            "Dynamic Postcard input does not match its schema"
        )
    }
}

/** Decode one dynamic value and return the remaining source bytes. */
public func takeDynamicWithFlavor(
    schema: NamedType,
    flavor: DeserializeFlavor
): (DynamicValue, Array<UInt8>) {
    let deserializer = Deserializer(flavor)
    try {
        let value = decodeValue(deserializer, schema)
        return (value, deserializer.finalize())
    } catch (error: DynamicException) {
        throw error
    } catch (error: PostcardException) {
        throw mapPostcardError(error)
    }
}

public func takeFromByteArrayDynamic(
    schema: NamedType,
    input: Array<UInt8>
): (DynamicValue, Array<UInt8>) {
    return takeDynamicWithFlavor(schema, SliceDeserializeFlavor(input))
}

public func fromByteArrayDynamic(schema: NamedType, input: Array<UInt8>): DynamicValue {
    let decoded = takeFromByteArrayDynamic(schema, input)
    if (decoded[1].size != 0) {
        throw DynamicException(
            DynamicErrorKind.SchemaMismatch,
            "Trailing bytes remain after dynamic value"
        )
    }
    return decoded[0]
}

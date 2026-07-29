package postcard4cj.schema

import postcard4cj.core.*
import postcard4cj.serde_model.*

private func writeNamedTypeArray(serializer: Serializer, values: Array<NamedType>): Unit {
    serializer.serializeSequence<NamedType>(
        values,
        {value: NamedType => value.serialize(serializer)}
    )
}

private func readNamedTypeArray(deserializer: Deserializer): Array<NamedType> {
    return deserializer.deserializeSequence<NamedType>({=> NamedType.deserialize(deserializer)})
}

private func writeNamedValueArray(serializer: Serializer, values: Array<NamedValue>): Unit {
    serializer.serializeSequence<NamedValue>(
        values,
        {value: NamedValue => value.serialize(serializer)}
    )
}

private func readNamedValueArray(deserializer: Deserializer): Array<NamedValue> {
    return deserializer.deserializeSequence<NamedValue>({=> NamedValue.deserialize(deserializer)})
}

private func writeNamedVariantArray(serializer: Serializer, values: Array<NamedVariant>): Unit {
    serializer.serializeSequence<NamedVariant>(
        values,
        {value: NamedVariant => value.serialize(serializer)}
    )
}

private func readNamedVariantArray(deserializer: Deserializer): Array<NamedVariant> {
    return deserializer.deserializeSequence<NamedVariant>({=> NamedVariant.deserialize(deserializer)})
}

extend NamedType <: PostcardSerialize & PostcardDeserialize<NamedType> {
    public func serialize(serializer: Serializer): Unit {
        serializer.beginStruct("NamedType", 2)
        serializer.serializeString(name)
        ty.serialize(serializer)
        serializer.endContainer()
    }

    public static func deserialize(deserializer: Deserializer): NamedType {
        deserializer.beginStruct("NamedType", 2)
        let name = deserializer.deserializeString()
        let ty = DataModelType.deserialize(deserializer)
        deserializer.endContainer()
        return NamedType(name, ty)
    }
}

extend NamedValue <: PostcardSerialize & PostcardDeserialize<NamedValue> {
    public func serialize(serializer: Serializer): Unit {
        serializer.beginStruct("NamedValue", 2)
        serializer.serializeString(name)
        ty.serialize(serializer)
        serializer.endContainer()
    }

    public static func deserialize(deserializer: Deserializer): NamedValue {
        deserializer.beginStruct("NamedValue", 2)
        let name = deserializer.deserializeString()
        let ty = NamedType.deserialize(deserializer)
        deserializer.endContainer()
        return NamedValue(name, ty)
    }
}

extend NamedVariant <: PostcardSerialize & PostcardDeserialize<NamedVariant> {
    public func serialize(serializer: Serializer): Unit {
        serializer.beginStruct("NamedVariant", 2)
        serializer.serializeString(name)
        ty.serialize(serializer)
        serializer.endContainer()
    }

    public static func deserialize(deserializer: Deserializer): NamedVariant {
        deserializer.beginStruct("NamedVariant", 2)
        let name = deserializer.deserializeString()
        let ty = DataModelVariant.deserialize(deserializer)
        deserializer.endContainer()
        return NamedVariant(name, ty)
    }
}

extend DataModelVariant <: PostcardSerialize & PostcardDeserialize<DataModelVariant> {
    public func serialize(serializer: Serializer): Unit {
        match (this) {
            case DataModelVariant.UnitVariant =>
                serializer.beginUnitVariant(0u32)
            case DataModelVariant.NewtypeVariant(inner) =>
                serializer.beginNewtypeVariant(1u32)
                inner.serialize(serializer)
            case DataModelVariant.TupleVariant(elements) =>
                serializer.beginNewtypeVariant(2u32)
                writeNamedTypeArray(serializer, elements)
            case DataModelVariant.StructVariant(fields) =>
                serializer.beginNewtypeVariant(3u32)
                writeNamedValueArray(serializer, fields)
        }
    }

    public static func deserialize(deserializer: Deserializer): DataModelVariant {
        let index = deserializer.deserializeVariantIndex()
        return match (index) {
            case 0u32 => DataModelVariant.UnitVariant
            case 1u32 => DataModelVariant.NewtypeVariant(NamedType.deserialize(deserializer))
            case 2u32 => DataModelVariant.TupleVariant(readNamedTypeArray(deserializer))
            case 3u32 => DataModelVariant.StructVariant(readNamedValueArray(deserializer))
            case _ => throw postcardException(PostcardErrorKind.DeserializeBadEnum)
        }
    }
}

extend DataModelType <: PostcardSerialize & PostcardDeserialize<DataModelType> {
    public func serialize(serializer: Serializer): Unit {
        match (this) {
            case DataModelType.Boolean => serializer.beginUnitVariant(0u32)
            case DataModelType.I8 => serializer.beginUnitVariant(1u32)
            case DataModelType.U8 => serializer.beginUnitVariant(2u32)
            case DataModelType.I16 => serializer.beginUnitVariant(3u32)
            case DataModelType.I32 => serializer.beginUnitVariant(4u32)
            case DataModelType.I64 => serializer.beginUnitVariant(5u32)
            case DataModelType.I128 => serializer.beginUnitVariant(6u32)
            case DataModelType.U16 => serializer.beginUnitVariant(7u32)
            case DataModelType.U32 => serializer.beginUnitVariant(8u32)
            case DataModelType.U64 => serializer.beginUnitVariant(9u32)
            case DataModelType.U128 => serializer.beginUnitVariant(10u32)
            case DataModelType.Usize => serializer.beginUnitVariant(11u32)
            case DataModelType.Isize => serializer.beginUnitVariant(12u32)
            case DataModelType.F32 => serializer.beginUnitVariant(13u32)
            case DataModelType.F64 => serializer.beginUnitVariant(14u32)
            case DataModelType.Char => serializer.beginUnitVariant(15u32)
            case DataModelType.StringValue => serializer.beginUnitVariant(16u32)
            case DataModelType.ByteArray => serializer.beginUnitVariant(17u32)
            case DataModelType.Option(inner) =>
                serializer.beginNewtypeVariant(18u32)
                inner.serialize(serializer)
            case DataModelType.UnitValue => serializer.beginUnitVariant(19u32)
            case DataModelType.UnitStruct => serializer.beginUnitVariant(20u32)
            case DataModelType.NewtypeStruct(inner) =>
                serializer.beginNewtypeVariant(21u32)
                inner.serialize(serializer)
            case DataModelType.Seq(inner) =>
                serializer.beginNewtypeVariant(22u32)
                inner.serialize(serializer)
            case DataModelType.Tuple(elements) =>
                serializer.beginNewtypeVariant(23u32)
                writeNamedTypeArray(serializer, elements)
            case DataModelType.TupleStruct(elements) =>
                serializer.beginNewtypeVariant(24u32)
                writeNamedTypeArray(serializer, elements)
            case DataModelType.Map(key, val) =>
                serializer.beginStructVariant(25u32, 2)
                key.serialize(serializer)
                val.serialize(serializer)
            case DataModelType.Struct(fields) =>
                serializer.beginNewtypeVariant(26u32)
                writeNamedValueArray(serializer, fields)
            case DataModelType.Enum(variants) =>
                serializer.beginNewtypeVariant(27u32)
                writeNamedVariantArray(serializer, variants)
            case DataModelType.Schema => serializer.beginUnitVariant(28u32)
        }
    }

    public static func deserialize(deserializer: Deserializer): DataModelType {
        let index = deserializer.deserializeVariantIndex()
        return match (index) {
            case 0u32 => DataModelType.Boolean
            case 1u32 => DataModelType.I8
            case 2u32 => DataModelType.U8
            case 3u32 => DataModelType.I16
            case 4u32 => DataModelType.I32
            case 5u32 => DataModelType.I64
            case 6u32 => DataModelType.I128
            case 7u32 => DataModelType.U16
            case 8u32 => DataModelType.U32
            case 9u32 => DataModelType.U64
            case 10u32 => DataModelType.U128
            case 11u32 => DataModelType.Usize
            case 12u32 => DataModelType.Isize
            case 13u32 => DataModelType.F32
            case 14u32 => DataModelType.F64
            case 15u32 => DataModelType.Char
            case 16u32 => DataModelType.StringValue
            case 17u32 => DataModelType.ByteArray
            case 18u32 => DataModelType.Option(NamedType.deserialize(deserializer))
            case 19u32 => DataModelType.UnitValue
            case 20u32 => DataModelType.UnitStruct
            case 21u32 => DataModelType.NewtypeStruct(NamedType.deserialize(deserializer))
            case 22u32 => DataModelType.Seq(NamedType.deserialize(deserializer))
            case 23u32 => DataModelType.Tuple(readNamedTypeArray(deserializer))
            case 24u32 => DataModelType.TupleStruct(readNamedTypeArray(deserializer))
            case 25u32 => DataModelType.Map(
                NamedType.deserialize(deserializer),
                NamedType.deserialize(deserializer)
            )
            case 26u32 => DataModelType.Struct(readNamedValueArray(deserializer))
            case 27u32 => DataModelType.Enum(readNamedVariantArray(deserializer))
            case 28u32 => DataModelType.Schema
            case _ => throw postcardException(PostcardErrorKind.DeserializeBadEnum)
        }
    }
}

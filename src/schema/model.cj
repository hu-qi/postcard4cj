package postcard4cj.schema

/** A runtime-owned schema describing one named Postcard type. */
public class NamedType {
    public let name: String
    public let ty: DataModelType

    public init(name: String, ty: DataModelType) {
        this.name = name
        this.ty = ty
    }
}

/** One named struct or struct-variant field. */
public class NamedValue {
    public let name: String
    public let ty: NamedType

    public init(name: String, ty: NamedType) {
        this.name = name
        this.ty = ty
    }
}

/** One named enum variant. */
public class NamedVariant {
    public let name: String
    public let ty: DataModelVariant

    public init(name: String, ty: DataModelVariant) {
        this.name = name
        this.ty = ty
    }
}

/** Complete Postcard/Serde data model plus the Schema node. */
public enum DataModelType {
    | Boolean
    | I8
    | U8
    | I16
    | I32
    | I64
    | I128
    | U16
    | U32
    | U64
    | U128
    | Usize
    | Isize
    | F32
    | F64
    | Char
    | StringValue
    | ByteArray
    | Option(NamedType)
    | UnitValue
    | UnitStruct
    | NewtypeStruct(NamedType)
    | Seq(NamedType)
    | Tuple(Array<NamedType>)
    | TupleStruct(Array<NamedType>)
    | Map(NamedType, NamedType)
    | Struct(Array<NamedValue>)
    | Enum(Array<NamedVariant>)
    | Schema
}

/** Data model nodes valid specifically as enum variants. */
public enum DataModelVariant {
    | UnitVariant
    | NewtypeVariant(NamedType)
    | TupleVariant(Array<NamedType>)
    | StructVariant(Array<NamedValue>)
}

/** Cangjie-native equivalent of postcard_schema::Schema. */
public interface PostcardSchema<T> {
    static func schema(): NamedType
}

public func schemaOf<T>(): NamedType where T <: PostcardSchema<T> {
    return T.schema()
}

public func boolSchema(): NamedType { return NamedType("bool", DataModelType.Boolean) }
public func int8Schema(): NamedType { return NamedType("i8", DataModelType.I8) }
public func uint8Schema(): NamedType { return NamedType("u8", DataModelType.U8) }
public func int16Schema(): NamedType { return NamedType("i16", DataModelType.I16) }
public func int32Schema(): NamedType { return NamedType("i32", DataModelType.I32) }
public func int64Schema(): NamedType { return NamedType("i64", DataModelType.I64) }
public func int128Schema(): NamedType { return NamedType("i128", DataModelType.I128) }
public func uint16Schema(): NamedType { return NamedType("u16", DataModelType.U16) }
public func uint32Schema(): NamedType { return NamedType("u32", DataModelType.U32) }
public func uint64Schema(): NamedType { return NamedType("u64", DataModelType.U64) }
public func uint128Schema(): NamedType { return NamedType("u128", DataModelType.U128) }
public func platformUIntSchema(): NamedType { return NamedType("usize", DataModelType.Usize) }
public func platformIntSchema(): NamedType { return NamedType("isize", DataModelType.Isize) }
public func float32Schema(): NamedType { return NamedType("f32", DataModelType.F32) }
public func float64Schema(): NamedType { return NamedType("f64", DataModelType.F64) }
public func runeSchema(): NamedType { return NamedType("char", DataModelType.Char) }
public func stringSchema(): NamedType { return NamedType("String", DataModelType.StringValue) }
public func byteArraySchema(): NamedType { return NamedType("[u8]", DataModelType.ByteArray) }
public func unitSchema(): NamedType { return NamedType("()", DataModelType.UnitValue) }
public func schemaSchema(): NamedType { return NamedType("NamedType", DataModelType.Schema) }

public func optionSchema(inner: NamedType): NamedType {
    return NamedType("Option<${inner.name}>", DataModelType.Option(inner))
}

public func sequenceSchema(inner: NamedType): NamedType {
    return NamedType("[${inner.name}]", DataModelType.Seq(inner))
}

public func tupleSchema(elements: Array<NamedType>): NamedType {
    return NamedType("Tuple", DataModelType.Tuple(elements))
}

public func tupleStructSchema(name: String, elements: Array<NamedType>): NamedType {
    return NamedType(name, DataModelType.TupleStruct(elements))
}

public func mapSchema(key: NamedType, value: NamedType): NamedType {
    return NamedType("Map<${key.name}, ${value.name}>", DataModelType.Map(key, value))
}

public func structSchema(name: String, fields: Array<NamedValue>): NamedType {
    return NamedType(name, DataModelType.Struct(fields))
}

public func enumSchema(name: String, variants: Array<NamedVariant>): NamedType {
    return NamedType(name, DataModelType.Enum(variants))
}

/** Deep-copy helper corresponding to conversion into upstream OwnedNamedType. */
public func toOwnedSchema(schema: NamedType): NamedType {
    return NamedType(schema.name, cloneDataModelType(schema.ty))
}

private func cloneNamedTypes(values: Array<NamedType>): Array<NamedType> {
    return Array<NamedType>(values.size, {index: Int64 => toOwnedSchema(values[index])})
}

private func cloneNamedValues(values: Array<NamedValue>): Array<NamedValue> {
    return Array<NamedValue>(values.size, {index: Int64 =>
        NamedValue(values[index].name, toOwnedSchema(values[index].ty))
    })
}

private func cloneNamedVariants(values: Array<NamedVariant>): Array<NamedVariant> {
    return Array<NamedVariant>(values.size, {index: Int64 =>
        NamedVariant(values[index].name, cloneDataModelVariant(values[index].ty))
    })
}

private func cloneDataModelVariant(value: DataModelVariant): DataModelVariant {
    return match (value) {
        case DataModelVariant.UnitVariant => DataModelVariant.UnitVariant
        case DataModelVariant.NewtypeVariant(inner) =>
            DataModelVariant.NewtypeVariant(toOwnedSchema(inner))
        case DataModelVariant.TupleVariant(elements) =>
            DataModelVariant.TupleVariant(cloneNamedTypes(elements))
        case DataModelVariant.StructVariant(fields) =>
            DataModelVariant.StructVariant(cloneNamedValues(fields))
    }
}

private func cloneDataModelType(value: DataModelType): DataModelType {
    return match (value) {
        case DataModelType.Boolean => DataModelType.Boolean
        case DataModelType.I8 => DataModelType.I8
        case DataModelType.U8 => DataModelType.U8
        case DataModelType.I16 => DataModelType.I16
        case DataModelType.I32 => DataModelType.I32
        case DataModelType.I64 => DataModelType.I64
        case DataModelType.I128 => DataModelType.I128
        case DataModelType.U16 => DataModelType.U16
        case DataModelType.U32 => DataModelType.U32
        case DataModelType.U64 => DataModelType.U64
        case DataModelType.U128 => DataModelType.U128
        case DataModelType.Usize => DataModelType.Usize
        case DataModelType.Isize => DataModelType.Isize
        case DataModelType.F32 => DataModelType.F32
        case DataModelType.F64 => DataModelType.F64
        case DataModelType.Char => DataModelType.Char
        case DataModelType.StringValue => DataModelType.StringValue
        case DataModelType.ByteArray => DataModelType.ByteArray
        case DataModelType.Option(inner) => DataModelType.Option(toOwnedSchema(inner))
        case DataModelType.UnitValue => DataModelType.UnitValue
        case DataModelType.UnitStruct => DataModelType.UnitStruct
        case DataModelType.NewtypeStruct(inner) =>
            DataModelType.NewtypeStruct(toOwnedSchema(inner))
        case DataModelType.Seq(inner) => DataModelType.Seq(toOwnedSchema(inner))
        case DataModelType.Tuple(elements) => DataModelType.Tuple(cloneNamedTypes(elements))
        case DataModelType.TupleStruct(elements) =>
            DataModelType.TupleStruct(cloneNamedTypes(elements))
        case DataModelType.Map(key, val) =>
            DataModelType.Map(toOwnedSchema(key), toOwnedSchema(val))
        case DataModelType.Struct(fields) => DataModelType.Struct(cloneNamedValues(fields))
        case DataModelType.Enum(variants) => DataModelType.Enum(cloneNamedVariants(variants))
        case DataModelType.Schema => DataModelType.Schema
    }
}

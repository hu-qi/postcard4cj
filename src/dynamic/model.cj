package postcard4cj.dynamic

import postcard4cj.schema.*
import std.math.numeric.*

public enum DynamicErrorKind {
    | UnexpectedEndOfData
    | ShouldSupportButDont
    | SchemaMismatch
}

public class DynamicException <: Exception {
    public let kind: DynamicErrorKind

    public init(kind: DynamicErrorKind, message: String) {
        super(message)
        this.kind = kind
    }
}

/** Explicit Option representation preserving None versus Some(Unit). */
public class DynamicOption {
    public let value: Option<DynamicValue>

    public init(value: Option<DynamicValue>) {
        this.value = value
    }
}

public class DynamicField {
    public let name: String
    public let value: DynamicValue

    public init(name: String, value: DynamicValue) {
        this.name = name
        this.value = value
    }
}

public class DynamicEntry {
    public let key: DynamicValue
    public let value: DynamicValue

    public init(key: DynamicValue, value: DynamicValue) {
        this.key = key
        this.value = value
    }
}

public enum DynamicEnumPayload {
    | UnitPayload
    | NewtypePayload(DynamicValue)
    | TuplePayload(Array<DynamicValue>)
    | StructPayload(Array<DynamicField>)
}

public class DynamicEnumValue {
    public let name: String
    public let payload: DynamicEnumPayload

    public init(name: String, payload: DynamicEnumPayload) {
        this.name = name
        this.payload = payload
    }
}

/** Lossless runtime value corresponding to the complete Postcard data model. */
public enum DynamicValue {
    | BooleanValue(Bool)
    | SignedValue(BigInt)
    | UnsignedValue(BigInt)
    | FloatValue(Float64)
    | RuneValue(Rune)
    | StringValue(String)
    | BytesValue(Array<UInt8>)
    | OptionValue(DynamicOption)
    | UnitValue
    | SequenceValue(Array<DynamicValue>)
    | TupleValue(Array<DynamicValue>)
    | MapValue(Array<DynamicEntry>)
    | StructValue(Array<DynamicField>)
    | EnumValue(DynamicEnumValue)
    | SchemaValue(NamedType)
}

public func dynamicNone(): DynamicValue {
    return DynamicValue.OptionValue(DynamicOption(None))
}

public func dynamicSome(value: DynamicValue): DynamicValue {
    return DynamicValue.OptionValue(DynamicOption(Some(value)))
}

public func dynamicField(name: String, value: DynamicValue): DynamicField {
    return DynamicField(name, value)
}

public func dynamicEntry(key: DynamicValue, value: DynamicValue): DynamicEntry {
    return DynamicEntry(key, value)
}

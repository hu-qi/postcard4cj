package postcard4cj.schema

import postcard4cj.serde_model.*
import std.math.numeric.*

private let FNV_BASIS: BigInt = BigInt.parse("14695981039346656037")
private let FNV_PRIME: BigInt = BigInt.parse("1099511628211")
private let U64_MASK: BigInt = BigInt.parse("18446744073709551615")

private func hashUpdate(state: BigInt, bytes: Array<UInt8>): BigInt {
    var current = state
    for (byte in bytes) {
        current = ((current ^ BigInt(byte)) * FNV_PRIME) & U64_MASK
    }
    return current
}

private func hashMarker(state: BigInt, marker: UInt8): BigInt {
    return hashUpdate(state, [marker])
}

private func hashNamedType(state: BigInt, value: NamedType): BigInt {
    // Upstream hash v2 intentionally excludes the type name to allow compatible
    // owned/borrowed representations to share a key.
    return hashDataModelType(state, value.ty)
}

private func hashNamedValue(state: BigInt, value: NamedValue): BigInt {
    let named = hashUpdate(state, value.name.toArray())
    return hashNamedType(named, value.ty)
}

private func hashNamedVariant(state: BigInt, value: NamedVariant): BigInt {
    let named = hashUpdate(state, value.name.toArray())
    return match (value.ty) {
        case DataModelVariant.UnitVariant => hashMarker(named, 0xb5u8)
        case DataModelVariant.NewtypeVariant(inner) =>
            hashNamedType(hashMarker(named, 0xdfu8), inner)
        case DataModelVariant.TupleVariant(elements) =>
            var current = hashMarker(named, 0xc7u8)
            for (element in elements) {
                current = hashNamedType(current, element)
            }
            current
        case DataModelVariant.StructVariant(fields) =>
            var current = hashMarker(named, 0x67u8)
            for (field in fields) {
                current = hashNamedValue(current, field)
            }
            current
    }
}

private func hashDataModelType(state: BigInt, value: DataModelType): BigInt {
    return match (value) {
        case DataModelType.Boolean => hashMarker(state, 0x11u8)
        case DataModelType.I8 => hashMarker(state, 0xc5u8)
        case DataModelType.U8 => hashMarker(state, 0x3du8)
        case DataModelType.I16 => hashMarker(state, 0x1du8)
        case DataModelType.I32 => hashMarker(state, 0x0du8)
        case DataModelType.I64 => hashMarker(state, 0x0bu8)
        case DataModelType.I128 => hashMarker(state, 0x02u8)
        case DataModelType.U16 => hashMarker(state, 0x83u8)
        case DataModelType.U32 => hashMarker(state, 0xd3u8)
        case DataModelType.U64 => hashMarker(state, 0x13u8)
        case DataModelType.U128 => hashMarker(state, 0x8bu8)
        case DataModelType.Usize => hashMarker(state, 0x6bu8)
        case DataModelType.Isize => hashMarker(state, 0xadu8)
        case DataModelType.F32 => hashMarker(state, 0xefu8)
        case DataModelType.F64 => hashMarker(state, 0x71u8)
        case DataModelType.Char => hashMarker(state, 0xc1u8)
        case DataModelType.StringValue => hashMarker(state, 0x25u8)
        case DataModelType.ByteArray => hashMarker(state, 0x65u8)
        case DataModelType.Option(inner) =>
            hashNamedType(hashMarker(state, 0x6du8), inner)
        case DataModelType.UnitValue => hashMarker(state, 0x47u8)
        case DataModelType.UnitStruct => hashMarker(state, 0xbfu8)
        case DataModelType.NewtypeStruct(inner) =>
            hashNamedType(hashMarker(state, 0x9du8), inner)
        case DataModelType.Seq(inner) =>
            hashNamedType(hashMarker(state, 0x03u8), inner)
        case DataModelType.Tuple(elements) =>
            var current = hashMarker(state, 0xa7u8)
            for (element in elements) {
                current = hashNamedType(current, element)
            }
            current
        case DataModelType.TupleStruct(elements) =>
            var current = hashMarker(state, 0x05u8)
            for (element in elements) {
                current = hashNamedType(current, element)
            }
            current
        case DataModelType.Map(key, val) =>
            let withMarker = hashMarker(state, 0x4fu8)
            hashNamedType(hashNamedType(withMarker, key), val)
        case DataModelType.Struct(fields) =>
            var current = hashMarker(state, 0x7fu8)
            for (field in fields) {
                current = hashNamedValue(current, field)
            }
            current
        case DataModelType.Enum(variants) =>
            var current = hashMarker(state, 0xe9u8)
            for (variant in variants) {
                current = hashNamedVariant(current, variant)
            }
            current
        case DataModelType.Schema => hashMarker(state, 0xb3u8)
    }
}

private func digestBytes(state: BigInt): Array<UInt8> {
    let output = Array<UInt8>(8, repeat: 0u8)
    var current = state
    var index = 0i64
    while (index < 8) {
        output[index] = (current & BigInt(0xffi64)).toUInt8()
        current = current >> 8i64
        index++
    }
    return output
}

/** Non-cryptographic, misuse-resistant schema/path dispatch key. */
public struct Key <: PostcardSerialize & PostcardDeserialize<Key> & PostcardSchema<Key> {
    private let bytes: Array<UInt8>

    public init(bytes: Array<UInt8>) {
        if (bytes.size != 8) {
            throw IllegalArgumentException("A Postcard schema Key must contain exactly 8 bytes")
        }
        this.bytes = bytes[0..8]
    }

    public func toBytes(): Array<UInt8> {
        return bytes[0..8]
    }

    public func constCompare(other: Key): Bool {
        var index = 0i64
        while (index < 8) {
            if (bytes[index] != other.bytes[index]) {
                return false
            }
            index++
        }
        return true
    }

    public func serialize(serializer: Serializer): Unit {
        for (byte in bytes) {
            serializer.serializeUInt8(byte)
        }
    }

    public static func deserialize(deserializer: Deserializer): Key {
        let bytes = Array<UInt8>(8, repeat: 0u8)
        var index = 0i64
        while (index < 8) {
            bytes[index] = deserializer.deserializeUInt8()
            index++
        }
        return Key(bytes)
    }

    public static func schema(): NamedType {
        let elements = Array<NamedType>(8, {_: Int64 => uint8Schema()})
        return NamedType("Key", DataModelType.NewtypeStruct(tupleSchema(elements)))
    }
}

public func keyForSchemaPath(path: String, schema: NamedType): Key {
    let withPath = hashUpdate(FNV_BASIS, path.toArray())
    return Key(digestBytes(hashNamedType(withPath, schema)))
}

public func keyForPath<T>(path: String): Key where T <: PostcardSchema<T> {
    return keyForSchemaPath(path, T.schema())
}

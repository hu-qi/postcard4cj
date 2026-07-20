package postcard4cj.serde_model

import postcard4cj.core.*
import postcard4cj.flavors.*
import std.collection.*
import std.math.numeric.*

/** Cangjie-native substitute for Serde Serialize. */
public interface PostcardSerialize {
    func serialize(serializer: Serializer): Unit
}

/** Cangjie-native substitute for Serde Deserialize. */
public interface PostcardDeserialize<T> {
    static func deserialize(deserializer: Deserializer): T
}

/**
 * Postcard serializer implementing the complete non-self-describing data model.
 * Storage and transformations are delegated to a composable SerializeFlavor.
 */
public class Serializer {
    private let output: SerializeFlavor

    public init(output: SerializeFlavor) {
        this.output = output
    }

    public func isHumanReadable(): Bool {
        return false
    }

    public func position(): Int64 {
        return output.position()
    }

    public func snapshot(): Array<UInt8> {
        return output.snapshot()
    }

    public func finalize(): Array<UInt8> {
        return output.finalize()
    }

    private func emit(write: (CoreEncoder) -> Unit): Unit {
        let encoder = CoreEncoder()
        write(encoder)
        output.tryExtend(encoder.toArray())
    }

    public func serializeBool(value: Bool): Unit {
        emit({encoder: CoreEncoder => encoder.pushBool(value)})
    }

    public func serializeInt8(value: Int8): Unit {
        emit({encoder: CoreEncoder => encoder.pushInt8(value)})
    }

    public func serializeInt16(value: Int16): Unit {
        emit({encoder: CoreEncoder => encoder.pushInt16(value)})
    }

    public func serializeInt32(value: Int32): Unit {
        emit({encoder: CoreEncoder => encoder.pushInt32(value)})
    }

    public func serializeInt64(value: Int64): Unit {
        emit({encoder: CoreEncoder => encoder.pushInt64(value)})
    }

    public func serializeInt128(value: BigInt): Unit {
        emit({encoder: CoreEncoder => encoder.pushInt128(value)})
    }

    public func serializeUInt8(value: UInt8): Unit {
        output.tryPush(value)
    }

    public func serializeUInt16(value: UInt16): Unit {
        emit({encoder: CoreEncoder => encoder.pushUInt16(value)})
    }

    public func serializeUInt32(value: UInt32): Unit {
        emit({encoder: CoreEncoder => encoder.pushUInt32(value)})
    }

    public func serializeUInt64(value: UInt64): Unit {
        emit({encoder: CoreEncoder => encoder.pushUInt64(value)})
    }

    public func serializeUInt128(value: BigInt): Unit {
        emit({encoder: CoreEncoder => encoder.pushUInt128(value)})
    }

    public func serializePlatformInt(value: Int64): Unit {
        serializeInt64(value)
    }

    public func serializePlatformUInt(value: UInt64): Unit {
        serializeUInt64(value)
    }

    public func serializeFloat32(value: Float32): Unit {
        emit({encoder: CoreEncoder => encoder.pushFloat32(value)})
    }

    public func serializeFloat64(value: Float64): Unit {
        emit({encoder: CoreEncoder => encoder.pushFloat64(value)})
    }

    public func serializeRune(value: Rune): Unit {
        emit({encoder: CoreEncoder => encoder.pushRune(value)})
    }

    public func serializeString(value: String): Unit {
        emit({encoder: CoreEncoder => encoder.pushString(value)})
    }

    public func serializeBytes(value: Array<UInt8>): Unit {
        emit({encoder: CoreEncoder => encoder.pushBytes(value)})
    }

    public func serializeNone(): Unit {
        output.tryPush(0u8)
    }

    public func serializeSome<T>(value: T, writeValue: (T) -> Unit): Unit {
        output.tryPush(1u8)
        writeValue(value)
    }

    /** Unit, unit structs, newtype structs, tuples and structs have no header. */
    public func serializeUnit(): Unit {}
    public func beginUnitStruct(name: String): Unit {}
    public func beginNewtypeStruct(name: String): Unit {}
    public func beginTuple(length: Int64): Unit {}
    public func beginTupleStruct(name: String, length: Int64): Unit {}
    public func beginStruct(name: String, fieldCount: Int64): Unit {}
    public func endContainer(): Unit {}

    public func beginUnitVariant(index: UInt32): Unit {
        serializeUInt32(index)
    }

    public func beginNewtypeVariant(index: UInt32): Unit {
        serializeUInt32(index)
    }

    public func beginTupleVariant(index: UInt32, length: Int64): Unit {
        serializeUInt32(index)
    }

    public func beginStructVariant(index: UInt32, fieldCount: Int64): Unit {
        serializeUInt32(index)
    }

    /** Postcard requires known sequence lengths. */
    public func beginSequence(length: Option<Int64>): Int64 {
        let knownLength = match (length) {
            case Some(value) => value
            case None => throw postcardException(PostcardErrorKind.SerializeSeqLengthUnknown)
        }
        emit({encoder: CoreEncoder => encoder.pushLength(knownLength)})
        return knownLength
    }

    /** Postcard requires known map lengths. */
    public func beginMap(length: Option<Int64>): Int64 {
        return beginSequence(length)
    }

    public func serializeSequence<T>(values: Array<T>, writeValue: (T) -> Unit): Unit {
        beginSequence(Some(values.size))
        for (value in values) {
            writeValue(value)
        }
    }

    public func serializeMapEntries<K, V>(
        entries: Array<(K, V)>,
        writeKey: (K) -> Unit,
        writeValue: (V) -> Unit
    ): Unit {
        beginMap(Some(entries.size))
        for (entry in entries) {
            writeKey(entry[0])
            writeValue(entry[1])
        }
    }

    /** Equivalent to Serde collect_str after formatting has produced a String. */
    public func collectString(value: String): Unit {
        serializeString(value)
    }
}

private let CONTINUATION_MASK: UInt8 = 0x80u8
private let PAYLOAD_MASK: UInt8 = 0x7fu8

private func rawByteToInt8(value: UInt8): Int8 {
    if (value <= 0x7fu8) {
        return Int8(value)
    }
    return Int8(Int16(value) - 256i16)
}

private func zigZagDecodeInt64(value: UInt64): Int64 {
    let magnitude = value >> 1
    if ((value & 1u64) == 0u64) {
        return Int64(magnitude)
    }
    return -Int64(magnitude) - 1i64
}

private func bigZero(): BigInt { return BigInt(0i64) }
private func bigOne(): BigInt { return BigInt(1i64) }

private func zigZagDecodeInt128(value: BigInt): BigInt {
    let magnitude = value >> 1i64
    if ((value & bigOne()) == bigZero()) {
        return magnitude
    }
    return bigZero() - magnitude - bigOne()
}

/** Postcard deserializer backed by a composable DeserializeFlavor. */
public class Deserializer {
    private let input: DeserializeFlavor

    public init(input: DeserializeFlavor) {
        this.input = input
    }

    public func isHumanReadable(): Bool {
        return false
    }

    public func position(): Int64 {
        return input.position()
    }

    public func finalize(): Array<UInt8> {
        return input.finalize()
    }

    public func deserializeAny(): Unit {
        throw postcardException(PostcardErrorKind.WontImplement)
    }

    public func deserializeBool(): Bool {
        let value = input.pop()
        if (value == 0u8) { return false }
        if (value == 1u8) { return true }
        throw postcardException(PostcardErrorKind.DeserializeBadBool)
    }

    public func deserializeInt8(): Int8 {
        return rawByteToInt8(input.pop())
    }

    public func deserializeInt16(): Int16 {
        return Int16(zigZagDecodeInt64(UInt64(deserializeUInt16())))
    }

    public func deserializeInt32(): Int32 {
        return Int32(zigZagDecodeInt64(UInt64(deserializeUInt32())))
    }

    public func deserializeInt64(): Int64 {
        return zigZagDecodeInt64(deserializeUInt64())
    }

    public func deserializeInt128(): BigInt {
        return zigZagDecodeInt128(deserializeUInt128())
    }

    public func deserializeUInt8(): UInt8 {
        return input.pop()
    }

    public func deserializeUInt16(): UInt16 {
        return UInt16(takeVarint64(3, 0x03u8))
    }

    public func deserializeUInt32(): UInt32 {
        return UInt32(takeVarint64(5, 0x0fu8))
    }

    public func deserializeUInt64(): UInt64 {
        return takeVarint64(10, 0x01u8)
    }

    public func deserializeUInt128(): BigInt {
        var result = bigZero()
        var byteIndex = 0i64
        while (byteIndex < 19i64) {
            let byte = input.pop()
            if (byteIndex == 18i64) {
                if ((byte & CONTINUATION_MASK) != 0u8 || byte > 0x03u8) {
                    throw postcardException(PostcardErrorKind.DeserializeBadVarint)
                }
            }
            result = result | (BigInt(byte & PAYLOAD_MASK) << (byteIndex * 7i64))
            if ((byte & CONTINUATION_MASK) == 0u8) {
                return result
            }
            byteIndex++
        }
        throw postcardException(PostcardErrorKind.DeserializeBadVarint)
    }

    public func deserializePlatformInt(): Int64 {
        return deserializeInt64()
    }

    public func deserializePlatformUInt(): UInt64 {
        return deserializeUInt64()
    }

    public func deserializeFloat32(): Float32 {
        let bits = UInt32(input.pop()) |
            (UInt32(input.pop()) << 8) |
            (UInt32(input.pop()) << 16) |
            (UInt32(input.pop()) << 24)
        return Float32.fromBits(bits)
    }

    public func deserializeFloat64(): Float64 {
        let bits = UInt64(input.pop()) |
            (UInt64(input.pop()) << 8) |
            (UInt64(input.pop()) << 16) |
            (UInt64(input.pop()) << 24) |
            (UInt64(input.pop()) << 32) |
            (UInt64(input.pop()) << 40) |
            (UInt64(input.pop()) << 48) |
            (UInt64(input.pop()) << 56)
        return Float64.fromBits(bits)
    }

    public func deserializeBytes(): Array<UInt8> {
        let length = deserializeLength()
        return input.tryTake(length)
    }

    public func deserializeString(): String {
        let bytes = deserializeBytes()
        try {
            return String.fromUtf8(bytes)
        } catch (_: Exception) {
            throw postcardException(PostcardErrorKind.DeserializeBadUtf8)
        }
    }

    public func deserializeRune(): Rune {
        let bytes = deserializeBytes()
        if (bytes.size < 1 || bytes.size > 4) {
            throw postcardException(PostcardErrorKind.DeserializeBadChar)
        }
        try {
            let decoded = Rune.fromUtf8(bytes, 0)
            if (decoded[1] != bytes.size) {
                throw postcardException(PostcardErrorKind.DeserializeBadChar)
            }
            return decoded[0]
        } catch (error: PostcardException) {
            throw error
        } catch (_: Exception) {
            throw postcardException(PostcardErrorKind.DeserializeBadChar)
        }
    }

    public func deserializeOption<T>(readValue: () -> T): Option<T> {
        let discriminant = input.pop()
        if (discriminant == 0u8) { return None }
        if (discriminant == 1u8) { return Some(readValue()) }
        throw postcardException(PostcardErrorKind.DeserializeBadOption)
    }

    public func deserializeUnit(): Unit { return () }
    public func beginUnitStruct(name: String): Unit { return () }
    public func beginNewtypeStruct(name: String): Unit { return () }
    public func beginTuple(length: Int64): Unit { return () }
    public func beginTupleStruct(name: String, length: Int64): Unit { return () }
    public func beginStruct(name: String, fieldCount: Int64): Unit { return () }
    public func endContainer(): Unit { return () }

    public func deserializeVariantIndex(): UInt32 {
        return deserializeUInt32()
    }

    public func beginUnitVariant(): Unit { return () }
    public func beginNewtypeVariant(): Unit { return () }
    public func beginTupleVariant(length: Int64): Unit { return () }
    public func beginStructVariant(fieldCount: Int64): Unit { return () }

    public func deserializeLength(): Int64 {
        let length = deserializeUInt64()
        if (length > 0x7fff_ffff_ffff_ffffu64) {
            throw postcardException(PostcardErrorKind.DeserializeBadEncoding)
        }
        return Int64(length)
    }

    public func beginSequence(): Int64 {
        return deserializeLength()
    }

    public func beginMap(): Int64 {
        return deserializeLength()
    }

    public func deserializeSequence<T>(readValue: () -> T): Array<T> {
        let length = beginSequence()
        let output = ArrayList<T>(length)
        var index = 0i64
        while (index < length) {
            output.add(readValue())
            index++
        }
        return output.toArray()
    }

    public func deserializeMapEntries<K, V>(
        readKey: () -> K,
        readValue: () -> V
    ): Array<(K, V)> {
        let length = beginMap()
        let output = ArrayList<(K, V)>(length)
        var index = 0i64
        while (index < length) {
            output.add((readKey(), readValue()))
            index++
        }
        return output.toArray()
    }

    private func takeVarint64(maxBytes: Int64, maxLastByte: UInt8): UInt64 {
        var result = 0u64
        var byteIndex = 0i64
        while (byteIndex < maxBytes) {
            let byte = input.pop()
            if (byteIndex == maxBytes - 1) {
                if ((byte & CONTINUATION_MASK) != 0u8 || byte > maxLastByte) {
                    throw postcardException(PostcardErrorKind.DeserializeBadVarint)
                }
            }
            result |= UInt64(byte & PAYLOAD_MASK) << (byteIndex * 7)
            if ((byte & CONTINUATION_MASK) == 0u8) {
                return result
            }
            byteIndex++
        }
        throw postcardException(PostcardErrorKind.DeserializeBadVarint)
    }
}

/** Serialize one value with an explicitly selected Flavor pipeline. */
public func serializeWithFlavor<T>(value: T, flavor: SerializeFlavor): Array<UInt8>
    where T <: PostcardSerialize {
    let serializer = Serializer(flavor)
    value.serialize(serializer)
    return serializer.finalize()
}

/** Serialize one value into a growable byte array. */
public func toByteArray<T>(value: T): Array<UInt8> where T <: PostcardSerialize {
    return serializeWithFlavor<T>(value, ArraySerializeFlavor())
}

/** Serialize one value into a caller-provided fixed buffer and return bytes used. */
public func toSlice<T>(value: T, buffer: Array<UInt8>): Int64 where T <: PostcardSerialize {
    let flavor = SliceSerializeFlavor(buffer)
    let serializer = Serializer(flavor)
    value.serialize(serializer)
    serializer.finalize()
    return serializer.position()
}

/** Calculate unflavored serialized size through the counting Flavor. */
public func serializedSize<T>(value: T): Int64 where T <: PostcardSerialize {
    let flavor = SizeSerializeFlavor()
    let serializer = Serializer(flavor)
    value.serialize(serializer)
    serializer.finalize()
    return serializer.position()
}

/** Deserialize exactly one value and reject trailing bytes. */
public func fromByteArray<T>(input: Array<UInt8>): T where T <: PostcardDeserialize<T> {
    let deserializer = Deserializer(SliceDeserializeFlavor(input))
    let value = T.deserialize(deserializer)
    if (deserializer.finalize().size != 0) {
        throw postcardException(PostcardErrorKind.DeserializeBadEncoding)
    }
    return value
}

/** Deserialize one value and return the unused remainder. */
public func takeFromByteArray<T>(input: Array<UInt8>): (T, Array<UInt8>)
    where T <: PostcardDeserialize<T> {
    let deserializer = Deserializer(SliceDeserializeFlavor(input))
    let value = T.deserialize(deserializer)
    return (value, deserializer.finalize())
}

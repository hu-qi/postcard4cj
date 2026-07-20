package postcard4cj

import std.collection.*

/**
 * Implemented by values that can encode themselves using the Postcard data model.
 */
public interface PostcardEncode {
    func encode(encoder: PostcardEncoder): Unit
}

/** Implemented by values that can be reconstructed from a Postcard decoder. */
public interface PostcardDecode<T> {
    static func decode(decoder: PostcardDecoder): T
}

/** Encodes a value into a newly allocated byte array. */
public func toBytes<T>(value: T): Array<UInt8> where T <: PostcardEncode {
    let encoder = PostcardEncoder()
    value.encode(encoder)
    return encoder.toArray()
}

/**
 * Encodes a value directly into a caller-provided fixed-capacity byte array.
 * Returns the number of bytes written.
 */
public func encodeTo<T>(value: T, buffer: Array<UInt8>): Int64 where T <: PostcardEncode {
    let encoder = PostcardEncoder(buffer)
    value.encode(encoder)
    return encoder.position()
}

/** Decodes exactly one value and rejects trailing bytes. */
public func fromBytes<T>(input: Array<UInt8>): T where T <: PostcardDecode<T> {
    let decoder = PostcardDecoder(input)
    let value = T.decode(decoder)
    if (decoder.remaining() != 0) {
        throw IllegalArgumentException("Trailing bytes after Postcard value")
    }
    return value
}

/** Decodes one value and returns the number of consumed bytes. */
public func takeFromBytes<T>(input: Array<UInt8>): (T, Int64) where T <: PostcardDecode<T> {
    let decoder = PostcardDecoder(input)
    let value = T.decode(decoder)
    return (value, decoder.position())
}

extend PostcardEncoder {
    /** Writes an IEEE-754 Float32 bit pattern in little-endian byte order. */
    public func writeFloat32(value: Float32): Unit {
        let bits = value.toBits()
        writeUInt8(UInt8(bits & 0xffu32))
        writeUInt8(UInt8((bits >> 8) & 0xffu32))
        writeUInt8(UInt8((bits >> 16) & 0xffu32))
        writeUInt8(UInt8((bits >> 24) & 0xffu32))
    }

    /** Writes an IEEE-754 Float64 bit pattern in little-endian byte order. */
    public func writeFloat64(value: Float64): Unit {
        let bits = value.toBits()
        writeUInt8(UInt8(bits & 0xffu64))
        writeUInt8(UInt8((bits >> 8) & 0xffu64))
        writeUInt8(UInt8((bits >> 16) & 0xffu64))
        writeUInt8(UInt8((bits >> 24) & 0xffu64))
        writeUInt8(UInt8((bits >> 32) & 0xffu64))
        writeUInt8(UInt8((bits >> 40) & 0xffu64))
        writeUInt8(UInt8((bits >> 48) & 0xffu64))
        writeUInt8(UInt8((bits >> 56) & 0xffu64))
    }

    /** Writes a Postcard Option discriminant and its value when present. */
    public func writeOption<T>(value: Option<T>, writeValue: (T) -> Unit): Unit {
        match (value) {
            case Some(inner) =>
                writeUInt8(1u8)
                writeValue(inner)
            case None => writeUInt8(0u8)
        }
    }

    /** Writes a dynamic sequence length and then its elements. */
    public func writeSequence<T>(values: Array<T>, writeValue: (T) -> Unit): Unit {
        writeSequenceLength(values.size)
        for (value in values) {
            writeValue(value)
        }
    }

    /** Writes a dynamic sequence or map entry count. */
    public func writeSequenceLength(length: Int64): Unit {
        if (length < 0) {
            throw IllegalArgumentException("Postcard sequence length cannot be negative")
        }
        writeUInt64(UInt64(length))
    }
}

extend PostcardDecoder {
    /** Reads an IEEE-754 Float32 bit pattern in little-endian byte order. */
    public func readFloat32(): Float32 {
        let bits = UInt32(readUInt8()) |
            (UInt32(readUInt8()) << 8) |
            (UInt32(readUInt8()) << 16) |
            (UInt32(readUInt8()) << 24)
        return Float32.fromBits(bits)
    }

    /** Reads an IEEE-754 Float64 bit pattern in little-endian byte order. */
    public func readFloat64(): Float64 {
        let bits = UInt64(readUInt8()) |
            (UInt64(readUInt8()) << 8) |
            (UInt64(readUInt8()) << 16) |
            (UInt64(readUInt8()) << 24) |
            (UInt64(readUInt8()) << 32) |
            (UInt64(readUInt8()) << 40) |
            (UInt64(readUInt8()) << 48) |
            (UInt64(readUInt8()) << 56)
        return Float64.fromBits(bits)
    }

    /** Reads a Postcard Option discriminant and its optional value. */
    public func readOption<T>(readValue: () -> T): Option<T> {
        let discriminant = readUInt8()
        if (discriminant == 0u8) {
            return None
        }
        if (discriminant == 1u8) {
            return Some(readValue())
        }
        throw IllegalArgumentException("Invalid Postcard Option discriminant")
    }

    /** Reads a dynamic sequence into an Array. */
    public func readSequence<T>(readValue: () -> T): Array<T> {
        let length = readSequenceLength()
        // Length comes from the wire and must not be trusted as an allocation size.
        // Any non-empty encoded element consumes at least one byte; zero-sized
        // elements are still supported because ArrayList can grow dynamically.
        let remainingBytes = remaining()
        let initialCapacity = if (length > remainingBytes) { remainingBytes } else { length }
        let output = ArrayList<T>(initialCapacity)
        var index = 0i64
        while (index < length) {
            output.add(readValue())
            index++
        }
        return output.toArray()
    }

    /** Reads a sequence or map count and converts it to an Array-safe Int64. */
    public func readSequenceLength(): Int64 {
        let length = readUInt64()
        if (length > 0x7fff_ffff_ffff_ffffu64) {
            throw IllegalArgumentException("Postcard sequence length exceeds Cangjie Int64 capacity")
        }
        return Int64(length)
    }
}

package postcard4cj

import std.collection.*

private let CONTINUATION_MASK: UInt8 = 0x80u8
private let PAYLOAD_MASK: UInt8 = 0x7fu8

/** Encodes an unsigned 64-bit integer using Postcard's unsigned varint format. */
public func encodeUInt64(input: UInt64): Array<UInt8> {
    let output = ArrayList<UInt8>(10)
    var value = input

    while (value >= 0x80u64) {
        output.add(UInt8(value & 0x7fu64) | CONTINUATION_MASK)
        value >>= 7
    }

    output.add(UInt8(value))
    return output.toArray()
}

/** Decodes one unsigned 64-bit Postcard varint and its consumed byte count. */
public func decodeUInt64(input: Array<UInt8>): (UInt64, Int64) {
    let decoder = PostcardDecoder(input)
    let value = decoder.readUInt64()
    return (value, decoder.position())
}

/** ZigZag encodes an Int64 exactly as Postcard/Serde does before varint encoding. */
public func zigZagEncodeInt64(value: Int64): UInt64 {
    if (value >= 0i64) {
        return UInt64(value) << 1
    }

    // Written this way to avoid overflowing on Int64.MIN.
    return (UInt64(-(value + 1i64)) << 1) | 1u64
}

/** Decodes a Postcard/Serde ZigZag encoded Int64. */
public func zigZagDecodeInt64(value: UInt64): Int64 {
    let magnitude = value >> 1
    if ((value & 1u64) == 0u64) {
        return Int64(magnitude)
    }

    // This also handles UInt64.MAX -> Int64.MIN without overflow.
    return -Int64(magnitude) - 1i64
}

private func int8ToRawByte(value: Int8): UInt8 {
    if (value >= 0i8) {
        return UInt8(value)
    }
    return UInt8(Int16(value) + 256i16)
}

private func rawByteToInt8(value: UInt8): Int8 {
    if (value <= 0x7fu8) {
        return Int8(value)
    }
    return Int8(Int16(value) - 256i16)
}

private interface PostcardOutput {
    func writeByte(value: UInt8): Unit
    func position(): Int64
    func snapshot(): Array<UInt8>
}

private class GrowablePostcardOutput <: PostcardOutput {
    private let bytes: ArrayList<UInt8>

    public init() {
        bytes = ArrayList<UInt8>()
    }

    public init(capacity: Int64) {
        bytes = ArrayList<UInt8>(capacity)
    }

    public func writeByte(value: UInt8): Unit {
        bytes.add(value)
    }

    public func position(): Int64 {
        return bytes.size
    }

    public func snapshot(): Array<UInt8> {
        return bytes.toArray()
    }
}

private class FixedPostcardOutput <: PostcardOutput {
    private let buffer: Array<UInt8>
    private var cursor: Int64

    public init(buffer: Array<UInt8>) {
        this.buffer = buffer
        cursor = 0
    }

    public func writeByte(value: UInt8): Unit {
        if (cursor >= buffer.size) {
            throw IllegalArgumentException("Postcard serialize buffer is full")
        }
        buffer[cursor] = value
        cursor++
    }

    public func position(): Int64 {
        return cursor
    }

    public func snapshot(): Array<UInt8> {
        return buffer[..cursor]
    }
}

/**
 * Stateful Postcard encoder backed by either a growable byte array or a
 * caller-provided fixed-capacity buffer.
 */
public class PostcardEncoder {
    private let output: PostcardOutput

    /** Creates a growable encoder. */
    public init() {
        output = GrowablePostcardOutput()
    }

    /** Creates a growable encoder with an initial capacity. */
    public init(capacity: Int64) {
        output = GrowablePostcardOutput(capacity)
    }

    /** Creates an encoder that writes directly into the supplied fixed buffer. */
    public init(buffer: Array<UInt8>) {
        output = FixedPostcardOutput(buffer)
    }

    public func position(): Int64 {
        return output.position()
    }

    public func writeUInt8(value: UInt8): Unit {
        output.writeByte(value)
    }

    public func writeUInt16(value: UInt16): Unit {
        writeUInt64(UInt64(value))
    }

    public func writeUInt32(value: UInt32): Unit {
        writeUInt64(UInt64(value))
    }

    /** Streams a UInt64 Varint directly to the selected output. */
    public func writeUInt64(input: UInt64): Unit {
        var value = input
        while (value >= 0x80u64) {
            output.writeByte(UInt8(value & 0x7fu64) | CONTINUATION_MASK)
            value >>= 7
        }
        output.writeByte(UInt8(value))
    }

    public func writeInt8(value: Int8): Unit {
        // Postcard encodes i8 as one raw two's-complement byte, not ZigZag.
        output.writeByte(int8ToRawByte(value))
    }

    public func writeInt16(value: Int16): Unit {
        writeUInt64(zigZagEncodeInt64(Int64(value)))
    }

    public func writeInt32(value: Int32): Unit {
        writeUInt64(zigZagEncodeInt64(Int64(value)))
    }

    public func writeInt64(value: Int64): Unit {
        writeUInt64(zigZagEncodeInt64(value))
    }

    public func writeBool(value: Bool): Unit {
        output.writeByte(if (value) { 1u8 } else { 0u8 })
    }

    public func writeBytes(value: Array<UInt8>): Unit {
        writeUInt64(UInt64(value.size))
        writeRawBytes(value)
    }

    public func writeString(value: String): Unit {
        writeBytes(value.toArray())
    }

    /** Returns a copy containing only bytes written so far. */
    public func toArray(): Array<UInt8> {
        return output.snapshot()
    }

    private func writeRawBytes(value: Array<UInt8>): Unit {
        for (byte in value) {
            output.writeByte(byte)
        }
    }
}

/** Stateful Postcard decoder over an immutable byte array. */
public class PostcardDecoder {
    private let input: Array<UInt8>
    private var cursor: Int64

    public init(input: Array<UInt8>) {
        this.input = input
        cursor = 0
    }

    public func position(): Int64 {
        return cursor
    }

    public func remaining(): Int64 {
        return input.size - cursor
    }

    public func readUInt8(): UInt8 {
        ensureAvailable(1)
        let value = input[cursor]
        cursor++
        return value
    }

    public func readUInt16(): UInt16 {
        return UInt16(readVarint(3, 0x03u8, "UInt16"))
    }

    public func readUInt32(): UInt32 {
        return UInt32(readVarint(5, 0x0fu8, "UInt32"))
    }

    public func readUInt64(): UInt64 {
        return readVarint(10, 0x01u8, "UInt64")
    }

    public func readInt8(): Int8 {
        return rawByteToInt8(readUInt8())
    }

    public func readInt16(): Int16 {
        return Int16(zigZagDecodeInt64(UInt64(readUInt16())))
    }

    public func readInt32(): Int32 {
        return Int32(zigZagDecodeInt64(UInt64(readUInt32())))
    }

    public func readInt64(): Int64 {
        return zigZagDecodeInt64(readUInt64())
    }

    public func readBool(): Bool {
        let value = readUInt8()
        if (value == 0u8) {
            return false
        }
        if (value == 1u8) {
            return true
        }
        throw IllegalArgumentException("Invalid Postcard bool discriminant")
    }

    public func readBytes(): Array<UInt8> {
        let length = readUInt64()
        let available = UInt64(remaining())
        if (length > available) {
            throw IllegalArgumentException("Unexpected end of Postcard byte sequence")
        }

        let count = Int64(length)
        let end = cursor + count
        let value = input[cursor..end]
        cursor = end
        return value
    }

    public func readString(): String {
        return String.fromUtf8(readBytes())
    }

    private func readVarint(maxBytes: Int64, maxLastByte: UInt8, typeName: String): UInt64 {
        var result = 0u64
        var byteIndex = 0i64

        while (byteIndex < maxBytes) {
            let byte = readUInt8()
            if (byteIndex == maxBytes - 1) {
                if ((byte & CONTINUATION_MASK) != 0u8 || byte > maxLastByte) {
                    throw IllegalArgumentException("Malformed Postcard ${typeName} varint")
                }
            }

            let payload = UInt64(byte & PAYLOAD_MASK)
            result |= payload << (byteIndex * 7)

            if ((byte & CONTINUATION_MASK) == 0u8) {
                return result
            }
            byteIndex++
        }

        throw IllegalArgumentException("Unterminated Postcard ${typeName} varint")
    }

    private func ensureAvailable(count: Int64): Unit {
        if (count < 0 || remaining() < count) {
            throw IllegalArgumentException("Unexpected end of Postcard input")
        }
    }
}

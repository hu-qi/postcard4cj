package postcard4cj.core

import std.collection.*
import std.math.numeric.*

private let CONTINUATION_MASK: UInt8 = 0x80u8
private let PAYLOAD_MASK: UInt8 = 0x7fu8

public enum PostcardOptionDiscriminant {
    | NoneValue
    | SomeValue
}

private interface CoreOutput {
    func writeByte(value: UInt8): Unit
    func position(): Int64
    func snapshot(): Array<UInt8>
}

private class GrowableCoreOutput <: CoreOutput {
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

private class FixedCoreOutput <: CoreOutput {
    private let buffer: Array<UInt8>
    private var cursor: Int64

    public init(buffer: Array<UInt8>) {
        this.buffer = buffer
        cursor = 0
    }

    public func writeByte(value: UInt8): Unit {
        if (cursor >= buffer.size) {
            throw postcardException(PostcardErrorKind.SerializeBufferFull)
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

private func zigZagEncodeInt64(value: Int64): UInt64 {
    if (value >= 0i64) {
        return UInt64(value) << 1
    }
    return (UInt64(-(value + 1i64)) << 1) | 1u64
}

private func zigZagDecodeInt64(value: UInt64): Int64 {
    let magnitude = value >> 1
    if ((value & 1u64) == 0u64) {
        return Int64(magnitude)
    }
    return -Int64(magnitude) - 1i64
}

private func bigZero(): BigInt {
    return BigInt(0i64)
}

private func bigOne(): BigInt {
    return BigInt(1i64)
}

private func uint128Limit(): BigInt {
    return bigOne() << 128i64
}

private func int128Minimum(): BigInt {
    return bigZero() - (bigOne() << 127i64)
}

private func int128Maximum(): BigInt {
    return (bigOne() << 127i64) - bigOne()
}

private func requireUInt128(value: BigInt): Unit {
    if (value < bigZero() || value >= uint128Limit()) {
        throw PostcardException(
            PostcardErrorKind.SerdeSerCustom,
            "Postcard UInt128 value is outside the Rust u128 range"
        )
    }
}

private func requireInt128(value: BigInt): Unit {
    if (value < int128Minimum() || value > int128Maximum()) {
        throw PostcardException(
            PostcardErrorKind.SerdeSerCustom,
            "Postcard Int128 value is outside the Rust i128 range"
        )
    }
}

private func zigZagEncodeInt128(value: BigInt): BigInt {
    requireInt128(value)
    if (value >= bigZero()) {
        return value << 1i64
    }
    return ((bigZero() - (value + bigOne())) << 1i64) | bigOne()
}

private func zigZagDecodeInt128(value: BigInt): BigInt {
    requireUInt128(value)
    let magnitude = value >> 1i64
    if ((value & bigOne()) == bigZero()) {
        return magnitude
    }
    return bigZero() - magnitude - bigOne()
}

/** Framework-independent writer for Postcard wire items. */
public class CoreEncoder {
    private let output: CoreOutput

    public init() {
        output = GrowableCoreOutput()
    }

    public init(capacity: Int64) {
        output = GrowableCoreOutput(capacity)
    }

    public init(buffer: Array<UInt8>) {
        output = FixedCoreOutput(buffer)
    }

    public func position(): Int64 {
        return output.position()
    }

    public func toArray(): Array<UInt8> {
        return output.snapshot()
    }

    public func pushBool(value: Bool): Unit {
        pushUInt8(if (value) { 1u8 } else { 0u8 })
    }

    public func pushInt8(value: Int8): Unit {
        pushUInt8(int8ToRawByte(value))
    }

    public func pushInt16(value: Int16): Unit {
        pushUInt64(zigZagEncodeInt64(Int64(value)))
    }

    public func pushInt32(value: Int32): Unit {
        pushUInt64(zigZagEncodeInt64(Int64(value)))
    }

    public func pushInt64(value: Int64): Unit {
        pushUInt64(zigZagEncodeInt64(value))
    }

    public func pushInt128(value: BigInt): Unit {
        pushUInt128(zigZagEncodeInt128(value))
    }

    public func pushUInt8(value: UInt8): Unit {
        output.writeByte(value)
    }

    public func pushUInt16(value: UInt16): Unit {
        pushUInt64(UInt64(value))
    }

    public func pushUInt32(value: UInt32): Unit {
        pushUInt64(UInt64(value))
    }

    public func pushUInt64(input: UInt64): Unit {
        var value = input
        while (value >= 0x80u64) {
            output.writeByte(UInt8(value & 0x7fu64) | CONTINUATION_MASK)
            value >>= 7
        }
        output.writeByte(UInt8(value))
    }

    public func pushUInt128(value: BigInt): Unit {
        requireUInt128(value)
        let payloadMask = BigInt(0x7fi64)
        let continuationThreshold = BigInt(0x80i64)
        var current = value
        while (current >= continuationThreshold) {
            pushUInt8((current & payloadMask).toUInt8() | CONTINUATION_MASK)
            current = current >> 7i64
        }
        pushUInt8(current.toUInt8())
    }

    /** Cangjie currently targets a 64-bit native integer in this port. */
    public func pushPlatformInt(value: Int64): Unit {
        pushInt64(value)
    }

    /** Cangjie currently targets a 64-bit native unsigned integer in this port. */
    public func pushPlatformUInt(value: UInt64): Unit {
        pushUInt64(value)
    }

    public func pushFloat32(value: Float32): Unit {
        let bits = value.toBits()
        pushUInt8(UInt8(bits & 0xffu32))
        pushUInt8(UInt8((bits >> 8) & 0xffu32))
        pushUInt8(UInt8((bits >> 16) & 0xffu32))
        pushUInt8(UInt8((bits >> 24) & 0xffu32))
    }

    public func pushFloat64(value: Float64): Unit {
        let bits = value.toBits()
        pushUInt8(UInt8(bits & 0xffu64))
        pushUInt8(UInt8((bits >> 8) & 0xffu64))
        pushUInt8(UInt8((bits >> 16) & 0xffu64))
        pushUInt8(UInt8((bits >> 24) & 0xffu64))
        pushUInt8(UInt8((bits >> 32) & 0xffu64))
        pushUInt8(UInt8((bits >> 40) & 0xffu64))
        pushUInt8(UInt8((bits >> 48) & 0xffu64))
        pushUInt8(UInt8((bits >> 56) & 0xffu64))
    }

    public func pushRune(value: Rune): Unit {
        let length = Rune.utf8Size(value)
        let buffer = Array<UInt8>(length, repeat: 0u8)
        let written = Rune.intoUtf8Array(value, buffer, 0)
        if (written != length) {
            throw postcardException(PostcardErrorKind.DeserializeBadChar)
        }
        pushBytes(buffer)
    }

    public func pushString(value: String): Unit {
        pushBytes(value.toArray())
    }

    public func pushBytes(value: Array<UInt8>): Unit {
        pushLength(value.size)
        for (byte in value) {
            pushUInt8(byte)
        }
    }

    public func pushLength(length: Int64): Unit {
        if (length < 0) {
            throw postcardException(PostcardErrorKind.SerdeSerCustom)
        }
        pushUInt64(UInt64(length))
    }

    public func pushOptionNone(): Unit {
        pushUInt8(0u8)
    }

    public func pushOptionSome(): Unit {
        pushUInt8(1u8)
    }

    public func pushDiscriminant(value: UInt32): Unit {
        pushUInt32(value)
    }

    /** Unit and aggregate headers occupy no bytes. */
    public func pushUnit(): Unit {}
}

/** Framework-independent reader for Postcard wire items. */
public class CoreDecoder {
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

    public func finalize(): Array<UInt8> {
        return input[cursor..input.size]
    }

    public func takeBool(): Bool {
        let value = takeUInt8()
        if (value == 0u8) {
            return false
        }
        if (value == 1u8) {
            return true
        }
        throw postcardException(PostcardErrorKind.DeserializeBadBool)
    }

    public func takeInt8(): Int8 {
        return rawByteToInt8(takeUInt8())
    }

    public func takeInt16(): Int16 {
        return Int16(zigZagDecodeInt64(UInt64(takeUInt16())))
    }

    public func takeInt32(): Int32 {
        return Int32(zigZagDecodeInt64(UInt64(takeUInt32())))
    }

    public func takeInt64(): Int64 {
        return zigZagDecodeInt64(takeUInt64())
    }

    public func takeInt128(): BigInt {
        return zigZagDecodeInt128(takeUInt128())
    }

    public func takeUInt8(): UInt8 {
        ensureAvailable(1)
        let value = input[cursor]
        cursor++
        return value
    }

    public func takeUInt16(): UInt16 {
        return UInt16(takeVarint64(3, 0x03u8))
    }

    public func takeUInt32(): UInt32 {
        return UInt32(takeVarint64(5, 0x0fu8))
    }

    public func takeUInt64(): UInt64 {
        return takeVarint64(10, 0x01u8)
    }

    public func takeUInt128(): BigInt {
        var result = bigZero()
        var byteIndex = 0i64
        while (byteIndex < 19i64) {
            let byte = takeUInt8()
            if (byteIndex == 18i64) {
                if ((byte & CONTINUATION_MASK) != 0u8 || byte > 0x03u8) {
                    throw postcardException(PostcardErrorKind.DeserializeBadVarint)
                }
            }
            let payload = BigInt(byte & PAYLOAD_MASK)
            result = result | (payload << (byteIndex * 7i64))
            if ((byte & CONTINUATION_MASK) == 0u8) {
                return result
            }
            byteIndex++
        }
        throw postcardException(PostcardErrorKind.DeserializeBadVarint)
    }

    public func takePlatformInt(): Int64 {
        return takeInt64()
    }

    public func takePlatformUInt(): UInt64 {
        return takeUInt64()
    }

    public func takeFloat32(): Float32 {
        let bits = UInt32(takeUInt8()) |
            (UInt32(takeUInt8()) << 8) |
            (UInt32(takeUInt8()) << 16) |
            (UInt32(takeUInt8()) << 24)
        return Float32.fromBits(bits)
    }

    public func takeFloat64(): Float64 {
        let bits = UInt64(takeUInt8()) |
            (UInt64(takeUInt8()) << 8) |
            (UInt64(takeUInt8()) << 16) |
            (UInt64(takeUInt8()) << 24) |
            (UInt64(takeUInt8()) << 32) |
            (UInt64(takeUInt8()) << 40) |
            (UInt64(takeUInt8()) << 48) |
            (UInt64(takeUInt8()) << 56)
        return Float64.fromBits(bits)
    }

    public func takeRune(): Rune {
        let bytes = takeBytes()
        if (bytes.size < 1 || bytes.size > 4) {
            throw postcardException(PostcardErrorKind.DeserializeBadChar)
        }
        let decoded = Rune.fromUtf8(bytes, 0)
        if (decoded[1] != bytes.size) {
            throw postcardException(PostcardErrorKind.DeserializeBadChar)
        }
        return decoded[0]
    }

    public func takeString(): String {
        return String.fromUtf8(takeBytes())
    }

    public func takeBytes(): Array<UInt8> {
        let length = takeLength()
        ensureAvailable(length)
        let end = cursor + length
        let value = input[cursor..end]
        cursor = end
        return value
    }

    public func takeLength(): Int64 {
        let value = takeUInt64()
        if (value > 0x7fff_ffff_ffff_ffffu64) {
            throw postcardException(PostcardErrorKind.DeserializeBadVarint)
        }
        return Int64(value)
    }

    public func takeOptionDiscriminant(): PostcardOptionDiscriminant {
        let value = takeUInt8()
        if (value == 0u8) {
            return PostcardOptionDiscriminant.NoneValue
        }
        if (value == 1u8) {
            return PostcardOptionDiscriminant.SomeValue
        }
        throw postcardException(PostcardErrorKind.DeserializeBadOption)
    }

    public func takeDiscriminant(): UInt32 {
        return takeUInt32()
    }

    public func takeUnit(): Unit {
        return ()
    }

    private func takeVarint64(maxBytes: Int64, maxLastByte: UInt8): UInt64 {
        var result = 0u64
        var byteIndex = 0i64
        while (byteIndex < maxBytes) {
            let byte = takeUInt8()
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

    private func ensureAvailable(count: Int64): Unit {
        if (count < 0 || remaining() < count) {
            throw postcardException(PostcardErrorKind.DeserializeUnexpectedEnd)
        }
    }
}

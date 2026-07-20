package postcard4cj

import std.collection.*
import std.math.numeric.*

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
        throw IllegalArgumentException("Postcard UInt128 value is outside the Rust u128 range")
    }
}

private func requireInt128(value: BigInt): Unit {
    if (value < int128Minimum() || value > int128Maximum()) {
        throw IllegalArgumentException("Postcard Int128 value is outside the Rust i128 range")
    }
}

public func encodeUInt128(value: BigInt): Array<UInt8> {
    requireUInt128(value)
    let output = ArrayList<UInt8>(19)
    let payloadMask = BigInt(0x7fi64)
    let continuationThreshold = BigInt(0x80i64)
    var current = value
    while (current >= continuationThreshold) {
        output.add((current & payloadMask).toUInt8() | 0x80u8)
        current = current >> 7i64
    }
    output.add(current.toUInt8())
    return output.toArray()
}

public func zigZagEncodeInt128(value: BigInt): BigInt {
    requireInt128(value)
    if (value >= bigZero()) {
        return value << 1i64
    }
    return ((bigZero() - (value + bigOne())) << 1i64) | bigOne()
}

public func zigZagDecodeInt128(value: BigInt): BigInt {
    requireUInt128(value)
    let magnitude = value >> 1i64
    if ((value & bigOne()) == bigZero()) {
        return magnitude
    }
    return bigZero() - magnitude - bigOne()
}

extend PostcardEncoder {
    public func writeUInt128(value: BigInt): Unit {
        requireUInt128(value)
        let payloadMask = BigInt(0x7fi64)
        let continuationThreshold = BigInt(0x80i64)
        var current = value
        while (current >= continuationThreshold) {
            writeUInt8((current & payloadMask).toUInt8() | 0x80u8)
            current = current >> 7i64
        }
        writeUInt8(current.toUInt8())
    }

    public func writeInt128(value: BigInt): Unit {
        writeUInt128(zigZagEncodeInt128(value))
    }
}

extend PostcardDecoder {
    public func readUInt128(): BigInt {
        var result = bigZero()
        var byteIndex = 0i64
        while (byteIndex < 19i64) {
            let byte = readUInt8()
            if (byteIndex == 18i64) {
                if ((byte & 0x80u8) != 0u8 || byte > 0x03u8) {
                    throw IllegalArgumentException("Malformed Postcard UInt128 varint")
                }
            }
            let payload = BigInt(byte & 0x7fu8)
            result = result | (payload << (byteIndex * 7i64))
            if ((byte & 0x80u8) == 0u8) {
                return result
            }
            byteIndex++
        }
        throw IllegalArgumentException("Unterminated Postcard UInt128 varint")
    }

    public func readInt128(): BigInt {
        return zigZagDecodeInt128(readUInt128())
    }
}

package postcard4cj.fixint

import postcard4cj.core.*
import postcard4cj.serde_model.*
import std.math.numeric.*

func fixZero(): BigInt { return BigInt(0i64) }
func fixOne(): BigInt { return BigInt(1i64) }

func fixUnsignedBig(value: UInt64): BigInt {
    return BigInt.parse(value.toString())
}

func fixRequireUnsigned(value: BigInt, bits: Int64): Unit {
    let limit = fixOne() << bits
    if (value < fixZero() || value >= limit) {
        throw PostcardException(
            PostcardErrorKind.SerdeSerCustom,
            "Fixed unsigned integer is outside its declared width"
        )
    }
}

func fixRequireSigned(value: BigInt, bits: Int64): Unit {
    let minimum = fixZero() - (fixOne() << (bits - 1))
    let maximum = (fixOne() << (bits - 1)) - fixOne()
    if (value < minimum || value > maximum) {
        throw PostcardException(
            PostcardErrorKind.SerdeSerCustom,
            "Fixed signed integer is outside its declared width"
        )
    }
}

func fixEncodeUnsigned(value: BigInt, bits: Int64, littleEndian: Bool): Array<UInt8> {
    fixRequireUnsigned(value, bits)
    let byteCount = bits / 8
    let output = Array<UInt8>(byteCount, repeat: 0u8)
    var current = value
    var index = 0i64
    while (index < byteCount) {
        let target = if (littleEndian) { index } else { byteCount - index - 1 }
        output[target] = (current & BigInt(0xffi64)).toUInt8()
        current = current >> 8i64
        index++
    }
    return output
}

func fixEncodeSigned(value: BigInt, bits: Int64, littleEndian: Bool): Array<UInt8> {
    fixRequireSigned(value, bits)
    let encoded = if (value < fixZero()) { value + (fixOne() << bits) } else { value }
    return fixEncodeUnsigned(encoded, bits, littleEndian)
}

func fixDecodeUnsigned(bytes: Array<UInt8>, littleEndian: Bool): BigInt {
    var result = fixZero()
    var index = 0i64
    while (index < bytes.size) {
        let source = if (littleEndian) { bytes.size - index - 1 } else { index }
        result = (result << 8i64) | BigInt(bytes[source])
        index++
    }
    return result
}

func fixDecodeSigned(bytes: Array<UInt8>, littleEndian: Bool): BigInt {
    let unsigned = fixDecodeUnsigned(bytes, littleEndian)
    let mostSignificant = if (littleEndian) { bytes[bytes.size - 1] } else { bytes[0] }
    if ((mostSignificant & 0x80u8) == 0u8) {
        return unsigned
    }
    return unsigned - (fixOne() << (bytes.size * 8))
}

func fixWriteRaw(serializer: Serializer, bytes: Array<UInt8>): Unit {
    for (byte in bytes) {
        serializer.serializeUInt8(byte)
    }
}

func fixReadRaw(deserializer: Deserializer, count: Int64): Array<UInt8> {
    let output = Array<UInt8>(count, repeat: 0u8)
    var index = 0i64
    while (index < count) {
        output[index] = deserializer.deserializeUInt8()
        index++
    }
    return output
}

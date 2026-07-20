package postcard4cj.fixint

import postcard4cj.serde_model.*
import std.math.numeric.*

public func serializeInt16LE(serializer: Serializer, value: Int16): Unit {
    fixWriteRaw(serializer, fixEncodeSigned(BigInt(Int64(value)), 16, true))
}
public func serializeInt16BE(serializer: Serializer, value: Int16): Unit {
    fixWriteRaw(serializer, fixEncodeSigned(BigInt(Int64(value)), 16, false))
}
public func deserializeInt16LE(deserializer: Deserializer): Int16 {
    return fixDecodeSigned(fixReadRaw(deserializer, 2), true).toInt16()
}
public func deserializeInt16BE(deserializer: Deserializer): Int16 {
    return fixDecodeSigned(fixReadRaw(deserializer, 2), false).toInt16()
}

public func serializeInt32LE(serializer: Serializer, value: Int32): Unit {
    fixWriteRaw(serializer, fixEncodeSigned(BigInt(Int64(value)), 32, true))
}
public func serializeInt32BE(serializer: Serializer, value: Int32): Unit {
    fixWriteRaw(serializer, fixEncodeSigned(BigInt(Int64(value)), 32, false))
}
public func deserializeInt32LE(deserializer: Deserializer): Int32 {
    return fixDecodeSigned(fixReadRaw(deserializer, 4), true).toInt32()
}
public func deserializeInt32BE(deserializer: Deserializer): Int32 {
    return fixDecodeSigned(fixReadRaw(deserializer, 4), false).toInt32()
}

public func serializeInt64LE(serializer: Serializer, value: Int64): Unit {
    fixWriteRaw(serializer, fixEncodeSigned(BigInt(value), 64, true))
}
public func serializeInt64BE(serializer: Serializer, value: Int64): Unit {
    fixWriteRaw(serializer, fixEncodeSigned(BigInt(value), 64, false))
}
public func deserializeInt64LE(deserializer: Deserializer): Int64 {
    return fixDecodeSigned(fixReadRaw(deserializer, 8), true).toInt64()
}
public func deserializeInt64BE(deserializer: Deserializer): Int64 {
    return fixDecodeSigned(fixReadRaw(deserializer, 8), false).toInt64()
}

public func serializeInt128LE(serializer: Serializer, value: BigInt): Unit {
    fixWriteRaw(serializer, fixEncodeSigned(value, 128, true))
}
public func serializeInt128BE(serializer: Serializer, value: BigInt): Unit {
    fixWriteRaw(serializer, fixEncodeSigned(value, 128, false))
}
public func deserializeInt128LE(deserializer: Deserializer): BigInt {
    return fixDecodeSigned(fixReadRaw(deserializer, 16), true)
}
public func deserializeInt128BE(deserializer: Deserializer): BigInt {
    return fixDecodeSigned(fixReadRaw(deserializer, 16), false)
}

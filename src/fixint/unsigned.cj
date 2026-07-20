package postcard4cj.fixint

import postcard4cj.serde_model.*
import std.math.numeric.*

public func serializeUInt16LE(serializer: Serializer, value: UInt16): Unit {
    fixWriteRaw(serializer, fixEncodeUnsigned(BigInt(value), 16, true))
}
public func serializeUInt16BE(serializer: Serializer, value: UInt16): Unit {
    fixWriteRaw(serializer, fixEncodeUnsigned(BigInt(value), 16, false))
}
public func deserializeUInt16LE(deserializer: Deserializer): UInt16 {
    return fixDecodeUnsigned(fixReadRaw(deserializer, 2), true).toUInt16()
}
public func deserializeUInt16BE(deserializer: Deserializer): UInt16 {
    return fixDecodeUnsigned(fixReadRaw(deserializer, 2), false).toUInt16()
}

public func serializeUInt32LE(serializer: Serializer, value: UInt32): Unit {
    fixWriteRaw(serializer, fixEncodeUnsigned(BigInt(value), 32, true))
}
public func serializeUInt32BE(serializer: Serializer, value: UInt32): Unit {
    fixWriteRaw(serializer, fixEncodeUnsigned(BigInt(value), 32, false))
}
public func deserializeUInt32LE(deserializer: Deserializer): UInt32 {
    return fixDecodeUnsigned(fixReadRaw(deserializer, 4), true).toUInt32()
}
public func deserializeUInt32BE(deserializer: Deserializer): UInt32 {
    return fixDecodeUnsigned(fixReadRaw(deserializer, 4), false).toUInt32()
}

public func serializeUInt64LE(serializer: Serializer, value: UInt64): Unit {
    fixWriteRaw(serializer, fixEncodeUnsigned(fixUnsignedBig(value), 64, true))
}
public func serializeUInt64BE(serializer: Serializer, value: UInt64): Unit {
    fixWriteRaw(serializer, fixEncodeUnsigned(fixUnsignedBig(value), 64, false))
}
public func deserializeUInt64LE(deserializer: Deserializer): UInt64 {
    return fixDecodeUnsigned(fixReadRaw(deserializer, 8), true).toUInt64()
}
public func deserializeUInt64BE(deserializer: Deserializer): UInt64 {
    return fixDecodeUnsigned(fixReadRaw(deserializer, 8), false).toUInt64()
}

public func serializeUInt128LE(serializer: Serializer, value: BigInt): Unit {
    fixWriteRaw(serializer, fixEncodeUnsigned(value, 128, true))
}
public func serializeUInt128BE(serializer: Serializer, value: BigInt): Unit {
    fixWriteRaw(serializer, fixEncodeUnsigned(value, 128, false))
}
public func deserializeUInt128LE(deserializer: Deserializer): BigInt {
    return fixDecodeUnsigned(fixReadRaw(deserializer, 16), true)
}
public func deserializeUInt128BE(deserializer: Deserializer): BigInt {
    return fixDecodeUnsigned(fixReadRaw(deserializer, 16), false)
}

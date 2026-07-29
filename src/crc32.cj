package postcard4cj

import postcard4cj.core.*
import std.collection.*

/**
 * Calculates CRC-32/ISCSI (CRC-32C/Castagnoli), matching the algorithm used by
 * postcard's official CRC32 examples.
 */
public func crc32Iscsi(input: Array<UInt8>): UInt32 {
    let digest = crc32IscsiDigest()
    for (byte in input) {
        digest.updateByte(byte)
    }
    return digest.checksum()
}

/** Calculates a caller-selected CRC32 digest. */
public func crc32(input: Array<UInt8>, digest: Crc32Digest): UInt32 {
    for (byte in input) {
        digest.updateByte(byte)
    }
    return digest.checksum()
}

/** Appends a caller-selected little-endian CRC32 checksum. */
public func appendCrc32(payload: Array<UInt8>, digest: Crc32Digest): Array<UInt8> {
    let checksum = crc32(payload, digest)
    let output = ArrayList<UInt8>(payload.size + 4)
    for (byte in payload) {
        output.add(byte)
    }
    output.add(UInt8(checksum & 0xffu32))
    output.add(UInt8((checksum >> 8) & 0xffu32))
    output.add(UInt8((checksum >> 16) & 0xffu32))
    output.add(UInt8((checksum >> 24) & 0xffu32))
    return output.toArray()
}

/** Appends a little-endian CRC-32/ISCSI checksum to serialized bytes. */
public func appendCrc32Iscsi(payload: Array<UInt8>): Array<UInt8> {
    return appendCrc32(payload, crc32IscsiDigest())
}

/** Validates and removes a caller-selected little-endian CRC32 trailer. */
public func verifyAndStripCrc32(
    message: Array<UInt8>,
    digest: Crc32Digest
): Array<UInt8> {
    if (message.size < 4) {
        throw IllegalArgumentException("Postcard CRC32 message is shorter than its checksum")
    }
    let payloadEnd = message.size - 4
    let payload = message[0..payloadEnd]
    let expected = crc32(payload, digest)
    let actual = UInt32(message[payloadEnd]) |
        (UInt32(message[payloadEnd + 1]) << 8) |
        (UInt32(message[payloadEnd + 2]) << 16) |
        (UInt32(message[payloadEnd + 3]) << 24)
    if (actual != expected) {
        throw IllegalArgumentException("Invalid Postcard CRC32 checksum")
    }
    return payload
}

/** Validates and removes a little-endian CRC-32/ISCSI trailer. */
public func verifyAndStripCrc32Iscsi(message: Array<UInt8>): Array<UInt8> {
    return verifyAndStripCrc32(message, crc32IscsiDigest())
}

/** Encodes one typed value with a caller-selected CRC32 digest. */
public func toBytesCrc32<T>(value: T, digest: Crc32Digest): Array<UInt8>
    where T <: PostcardEncode {
    return appendCrc32(toBytes(value), digest)
}

/** Encodes one typed value and appends CRC-32/ISCSI. */
public func toBytesCrc32Iscsi<T>(value: T): Array<UInt8> where T <: PostcardEncode {
    return toBytesCrc32(value, crc32IscsiDigest())
}

/** Writes a caller-selected CRC32-framed value into a fixed buffer. */
public func encodeToCrc32<T>(
    value: T,
    buffer: Array<UInt8>,
    digest: Crc32Digest
): Int64 where T <: PostcardEncode {
    let message = toBytesCrc32<T>(value, digest)
    if (message.size > buffer.size) {
        throw IllegalArgumentException("Postcard CRC32 serialize buffer is full")
    }
    var index = 0i64
    while (index < message.size) {
        buffer[index] = message[index]
        index++
    }
    return message.size
}

/** Validates a caller-selected CRC32 checksum and decodes one typed value. */
public func fromBytesCrc32<T>(message: Array<UInt8>, digest: Crc32Digest): T
    where T <: PostcardDecode<T> {
    return fromBytes<T>(verifyAndStripCrc32(message, digest))
}

/** Writes a CRC32C-framed typed value into a caller-provided fixed buffer. */
public func encodeToCrc32Iscsi<T>(value: T, buffer: Array<UInt8>): Int64
    where T <: PostcardEncode {
    return encodeToCrc32(value, buffer, crc32IscsiDigest())
}

/** Validates CRC-32/ISCSI and decodes exactly one typed value. */
public func fromBytesCrc32Iscsi<T>(message: Array<UInt8>): T where T <: PostcardDecode<T> {
    return fromBytes<T>(verifyAndStripCrc32Iscsi(message))
}

/** Verifies a caller-selected immediate CRC32 trailer and returns remainder. */
public func takeFromBytesCrc32<T>(
    input: Array<UInt8>,
    digest: Crc32Digest
): (T, Array<UInt8>) where T <: PostcardDecode<T> {
    let decoded = takeFromBytes<T>(input)
    let payloadEnd = decoded[1]
    let messageEnd = payloadEnd + 4
    if (messageEnd > input.size) {
        throw IllegalArgumentException("Postcard CRC32 input is missing its checksum")
    }
    verifyAndStripCrc32(input[..messageEnd], digest)
    return (decoded[0], input[messageEnd..input.size])
}

/**
 * Decodes one value, verifies the immediately following CRC32C trailer, and
 * returns the unconsumed bytes after that trailer.
 */
public func takeFromBytesCrc32Iscsi<T>(input: Array<UInt8>): (T, Array<UInt8>)
    where T <: PostcardDecode<T> {
    return takeFromBytesCrc32(input, crc32IscsiDigest())
}

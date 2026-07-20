package postcard4cj

import std.collection.*

private let CRC32C_REFLECTED_POLYNOMIAL: UInt32 = 0x82f63b78u32

/**
 * Calculates CRC-32/ISCSI (CRC-32C/Castagnoli), matching the algorithm used by
 * postcard's official CRC32 examples.
 */
public func crc32Iscsi(input: Array<UInt8>): UInt32 {
    var crc = 0xffff_ffffu32

    for (byte in input) {
        crc ^= UInt32(byte)
        var bit = 0i64
        while (bit < 8) {
            if ((crc & 1u32) != 0u32) {
                crc = (crc >> 1) ^ CRC32C_REFLECTED_POLYNOMIAL
            } else {
                crc >>= 1
            }
            bit++
        }
    }

    return crc ^ 0xffff_ffffu32
}

/** Appends a little-endian CRC-32/ISCSI checksum to serialized bytes. */
public func appendCrc32Iscsi(payload: Array<UInt8>): Array<UInt8> {
    let checksum = crc32Iscsi(payload)
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

/** Validates and removes a little-endian CRC-32/ISCSI trailer. */
public func verifyAndStripCrc32Iscsi(message: Array<UInt8>): Array<UInt8> {
    if (message.size < 4) {
        throw IllegalArgumentException("Postcard CRC32 message is shorter than its checksum")
    }

    let payloadEnd = message.size - 4
    let payload = message[0..payloadEnd]
    let expected = crc32Iscsi(payload)
    let actual = UInt32(message[payloadEnd]) |
        (UInt32(message[payloadEnd + 1]) << 8) |
        (UInt32(message[payloadEnd + 2]) << 16) |
        (UInt32(message[payloadEnd + 3]) << 24)

    if (actual != expected) {
        throw IllegalArgumentException("Invalid Postcard CRC32 checksum")
    }

    return payload
}

/** Encodes one typed value and appends CRC-32/ISCSI. */
public func toBytesCrc32Iscsi<T>(value: T): Array<UInt8> where T <: PostcardEncode {
    return appendCrc32Iscsi(toBytes(value))
}

/** Writes a CRC32C-framed typed value into a caller-provided fixed buffer. */
public func encodeToCrc32Iscsi<T>(value: T, buffer: Array<UInt8>): Int64
    where T <: PostcardEncode {
    let message = toBytesCrc32Iscsi<T>(value)
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

/** Validates CRC-32/ISCSI and decodes exactly one typed value. */
public func fromBytesCrc32Iscsi<T>(message: Array<UInt8>): T where T <: PostcardDecode<T> {
    return fromBytes<T>(verifyAndStripCrc32Iscsi(message))
}

/**
 * Decodes one value, verifies the immediately following CRC32C trailer, and
 * returns the unconsumed bytes after that trailer.
 */
public func takeFromBytesCrc32Iscsi<T>(input: Array<UInt8>): (T, Array<UInt8>)
    where T <: PostcardDecode<T> {
    let decoded = takeFromBytes<T>(input)
    let payloadEnd = decoded[1]
    let messageEnd = payloadEnd + 4
    if (messageEnd > input.size) {
        throw IllegalArgumentException("Postcard CRC32 input is missing its checksum")
    }
    verifyAndStripCrc32Iscsi(input[..messageEnd])
    return (decoded[0], input[messageEnd..input.size])
}

package postcard4cj

import std.collection.*

/**
 * Encodes bytes using canonical Consistent Overhead Byte Stuffing and appends
 * the zero frame delimiter used by Rust postcard's COBS helpers.
 */
public func cobsEncode(input: Array<UInt8>): Array<UInt8> {
    let output = ArrayList<UInt8>(input.size + input.size / 254 + 2)
    var segmentStart = 0i64

    // A trailing zero creates a final empty segment, so segmentStart may equal
    // input.size and must still be emitted as code 0x01.
    while (segmentStart <= input.size) {
        var segmentEnd = segmentStart
        while (segmentEnd < input.size && input[segmentEnd] != 0u8) {
            segmentEnd++
        }

        var cursor = segmentStart
        var remaining = segmentEnd - segmentStart

        while (remaining >= 254) {
            output.add(0xffu8)
            var copied = 0i64
            while (copied < 254) {
                output.add(input[cursor + copied])
                copied++
            }
            cursor += 254
            remaining -= 254
        }

        // Every segment ends with a short block, including an empty block after
        // an exact multiple of 254 bytes. This is required to preserve a zero
        // separator and to terminate an exact-length final run canonically.
        output.add(UInt8(remaining + 1))
        var copied = 0i64
        while (copied < remaining) {
            output.add(input[cursor + copied])
            copied++
        }

        if (segmentEnd == input.size) {
            break
        }
        segmentStart = segmentEnd + 1
    }

    output.add(0u8)
    return output.toArray()
}

/** Decodes one complete zero-terminated COBS frame. */
public func cobsDecode(frame: Array<UInt8>): Array<UInt8> {
    if (frame.size < 2 || frame[frame.size - 1] != 0u8) {
        throw IllegalArgumentException("Postcard COBS frame must end with one zero delimiter")
    }

    let encodedEnd = frame.size - 1
    let output = ArrayList<UInt8>(encodedEnd)
    var cursor = 0i64

    while (cursor < encodedEnd) {
        let code = frame[cursor]
        if (code == 0u8) {
            throw IllegalArgumentException("Unexpected zero inside Postcard COBS frame")
        }
        cursor++

        let payloadLength = Int64(code) - 1
        if (cursor + payloadLength > encodedEnd) {
            throw IllegalArgumentException("Truncated Postcard COBS block")
        }

        var copied = 0i64
        while (copied < payloadLength) {
            let byte = frame[cursor + copied]
            if (byte == 0u8) {
                throw IllegalArgumentException("Unexpected zero inside Postcard COBS payload")
            }
            output.add(byte)
            copied++
        }
        cursor += payloadLength

        if (code != 0xffu8 && cursor < encodedEnd) {
            output.add(0u8)
        }
    }

    return output.toArray()
}

/** Encodes a typed Postcard value and applies zero-terminated COBS framing. */
public func toBytesCobs<T>(value: T): Array<UInt8> where T <: PostcardEncode {
    return cobsEncode(toBytes(value))
}

/** Writes a COBS-framed typed value into a caller-provided fixed buffer. */
public func encodeToCobs<T>(value: T, buffer: Array<UInt8>): Int64
    where T <: PostcardEncode {
    let frame = toBytesCobs<T>(value)
    if (frame.size > buffer.size) {
        throw IllegalArgumentException("Postcard COBS serialize buffer is full")
    }
    var index = 0i64
    while (index < frame.size) {
        buffer[index] = frame[index]
        index++
    }
    return frame.size
}

/** Decodes a zero-terminated COBS frame into exactly one typed value. */
public func fromBytesCobs<T>(frame: Array<UInt8>): T where T <: PostcardDecode<T> {
    return fromBytes<T>(cobsDecode(frame))
}

/**
 * Decodes the first zero-terminated COBS frame and returns bytes following its
 * delimiter, matching postcard::take_from_bytes_cobs semantics.
 */
public func takeFromBytesCobs<T>(input: Array<UInt8>): (T, Array<UInt8>)
    where T <: PostcardDecode<T> {
    var delimiter = -1i64
    var index = 0i64
    while (index < input.size) {
        if (input[index] == 0u8) {
            delimiter = index
            break
        }
        index++
    }
    if (delimiter < 0) {
        throw IllegalArgumentException("Postcard COBS input has no frame delimiter")
    }
    let frameEnd = delimiter + 1
    return (
        fromBytesCobs<T>(input[..frameEnd]),
        input[frameEnd..input.size]
    )
}

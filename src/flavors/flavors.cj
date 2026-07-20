package postcard4cj.flavors

import postcard4cj.core.*
import std.collection.*

/**
 * Cangjie-native equivalent of Postcard's serialization Flavor abstraction.
 *
 * Flavors may store bytes directly or buffer and transform them before passing
 * them to an inner flavor. All failures use the stable Postcard error model.
 */
public interface SerializeFlavor {
    func tryPush(data: UInt8): Unit
    func tryExtend(data: Array<UInt8>): Unit
    func position(): Int64
    func snapshot(): Array<UInt8>
    func finalize(): Array<UInt8>
}

/** Growable byte storage flavor. */
public class ArraySerializeFlavor <: SerializeFlavor {
    private let bytes: ArrayList<UInt8>

    public init() {
        bytes = ArrayList<UInt8>()
    }

    public init(capacity: Int64) {
        bytes = ArrayList<UInt8>(capacity)
    }

    public func tryPush(data: UInt8): Unit {
        bytes.add(data)
    }

    public func tryExtend(data: Array<UInt8>): Unit {
        for (byte in data) {
            bytes.add(byte)
        }
    }

    public func position(): Int64 {
        return bytes.size
    }

    public func snapshot(): Array<UInt8> {
        return bytes.toArray()
    }

    public func finalize(): Array<UInt8> {
        return snapshot()
    }
}

/** Caller-provided fixed-capacity storage flavor. */
public class SliceSerializeFlavor <: SerializeFlavor {
    private let buffer: Array<UInt8>
    private var cursor: Int64

    public init(buffer: Array<UInt8>) {
        this.buffer = buffer
        cursor = 0
    }

    public func tryPush(data: UInt8): Unit {
        if (cursor >= buffer.size) {
            throw postcardException(PostcardErrorKind.SerializeBufferFull)
        }
        buffer[cursor] = data
        cursor++
    }

    public func tryExtend(data: Array<UInt8>): Unit {
        if (data.size > buffer.size - cursor) {
            throw postcardException(PostcardErrorKind.SerializeBufferFull)
        }
        for (byte in data) {
            buffer[cursor] = byte
            cursor++
        }
    }

    public func position(): Int64 {
        return cursor
    }

    public func snapshot(): Array<UInt8> {
        return buffer[..cursor]
    }

    public func finalize(): Array<UInt8> {
        return snapshot()
    }
}

/** Counting flavor used by serialized-size calculation. */
public class SizeSerializeFlavor <: SerializeFlavor {
    private var count: Int64

    public init() {
        count = 0
    }

    public func tryPush(data: UInt8): Unit {
        count++
    }

    public func tryExtend(data: Array<UInt8>): Unit {
        count += data.size
    }

    public func position(): Int64 {
        return count
    }

    public func snapshot(): Array<UInt8> {
        return []
    }

    public func finalize(): Array<UInt8> {
        return []
    }
}

private func encodeCobs(input: Array<UInt8>): Array<UInt8> {
    let output = ArrayList<UInt8>(input.size + input.size / 254 + 2)
    var segmentStart = 0i64

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

private func decodeCobs(frame: Array<UInt8>): Array<UInt8> {
    if (frame.size < 2 || frame[frame.size - 1] != 0u8) {
        throw postcardException(PostcardErrorKind.DeserializeBadEncoding)
    }

    let encodedEnd = frame.size - 1
    let output = ArrayList<UInt8>(encodedEnd)
    var cursor = 0i64

    while (cursor < encodedEnd) {
        let code = frame[cursor]
        if (code == 0u8) {
            throw postcardException(PostcardErrorKind.DeserializeBadEncoding)
        }
        cursor++

        let payloadLength = Int64(code) - 1
        if (cursor + payloadLength > encodedEnd) {
            throw postcardException(PostcardErrorKind.DeserializeBadEncoding)
        }

        var copied = 0i64
        while (copied < payloadLength) {
            let byte = frame[cursor + copied]
            if (byte == 0u8) {
                throw postcardException(PostcardErrorKind.DeserializeBadEncoding)
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

private let CRC32C_REFLECTED_POLYNOMIAL: UInt32 = 0x82f63b78u32

private func crc32c(input: Array<UInt8>): UInt32 {
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

private func appendCrc32c(input: Array<UInt8>): Array<UInt8> {
    let checksum = crc32c(input)
    let output = ArrayList<UInt8>(input.size + 4)
    for (byte in input) {
        output.add(byte)
    }
    output.add(UInt8(checksum & 0xffu32))
    output.add(UInt8((checksum >> 8) & 0xffu32))
    output.add(UInt8((checksum >> 16) & 0xffu32))
    output.add(UInt8((checksum >> 24) & 0xffu32))
    return output.toArray()
}

private func stripAndVerifyCrc32c(input: Array<UInt8>): Array<UInt8> {
    if (input.size < 4) {
        throw postcardException(PostcardErrorKind.DeserializeBadCrc)
    }
    let payloadEnd = input.size - 4
    let payload = input[..payloadEnd]
    let expected = crc32c(payload)
    let actual = UInt32(input[payloadEnd]) |
        (UInt32(input[payloadEnd + 1]) << 8) |
        (UInt32(input[payloadEnd + 2]) << 16) |
        (UInt32(input[payloadEnd + 3]) << 24)
    if (actual != expected) {
        throw postcardException(PostcardErrorKind.DeserializeBadCrc)
    }
    return payload
}

/** COBS middleware flavor. It transforms bytes before finalizing its inner flavor. */
public class CobsSerializeFlavor <: SerializeFlavor {
    private let inner: SerializeFlavor
    private let raw: ArrayList<UInt8>

    public init(inner: SerializeFlavor) {
        this.inner = inner
        raw = ArrayList<UInt8>()
    }

    public func tryPush(data: UInt8): Unit {
        raw.add(data)
    }

    public func tryExtend(data: Array<UInt8>): Unit {
        for (byte in data) {
            raw.add(byte)
        }
    }

    public func position(): Int64 {
        return raw.size
    }

    public func snapshot(): Array<UInt8> {
        return encodeCobs(raw.toArray())
    }

    public func finalize(): Array<UInt8> {
        inner.tryExtend(snapshot())
        return inner.finalize()
    }
}

/** CRC-32/ISCSI middleware flavor. */
public class Crc32SerializeFlavor <: SerializeFlavor {
    private let inner: SerializeFlavor
    private let raw: ArrayList<UInt8>

    public init(inner: SerializeFlavor) {
        this.inner = inner
        raw = ArrayList<UInt8>()
    }

    public func tryPush(data: UInt8): Unit {
        raw.add(data)
    }

    public func tryExtend(data: Array<UInt8>): Unit {
        for (byte in data) {
            raw.add(byte)
        }
    }

    public func position(): Int64 {
        return raw.size
    }

    public func snapshot(): Array<UInt8> {
        return appendCrc32c(raw.toArray())
    }

    public func finalize(): Array<UInt8> {
        inner.tryExtend(snapshot())
        return inner.finalize()
    }
}

/** Source abstraction corresponding to Postcard deserialization Flavors. */
public interface DeserializeFlavor {
    func pop(): UInt8
    func tryTake(count: Int64): Array<UInt8>
    func sizeHint(): Option<Int64>
    func position(): Int64
    func finalize(): Array<UInt8>
}

/** Borrowing-equivalent slice source. Arrays are reference-backed in this Cangjie port. */
public class SliceDeserializeFlavor <: DeserializeFlavor {
    private let input: Array<UInt8>
    private var cursor: Int64

    public init(input: Array<UInt8>) {
        this.input = input
        cursor = 0
    }

    public func pop(): UInt8 {
        if (cursor >= input.size) {
            throw postcardException(PostcardErrorKind.DeserializeUnexpectedEnd)
        }
        let value = input[cursor]
        cursor++
        return value
    }

    public func tryTake(count: Int64): Array<UInt8> {
        if (count < 0 || count > input.size - cursor) {
            throw postcardException(PostcardErrorKind.DeserializeUnexpectedEnd)
        }
        let end = cursor + count
        let output = input[cursor..end]
        cursor = end
        return output
    }

    public func sizeHint(): Option<Int64> {
        return Some(input.size - cursor)
    }

    public func position(): Int64 {
        return cursor
    }

    public func finalize(): Array<UInt8> {
        return input[cursor..input.size]
    }
}

/** Decodes one complete zero-terminated COBS frame into a slice source. */
public class CobsDeserializeFlavor <: DeserializeFlavor {
    private let source: SliceDeserializeFlavor

    public init(frame: Array<UInt8>) {
        source = SliceDeserializeFlavor(decodeCobs(frame))
    }

    public func pop(): UInt8 { return source.pop() }
    public func tryTake(count: Int64): Array<UInt8> { return source.tryTake(count) }
    public func sizeHint(): Option<Int64> { return source.sizeHint() }
    public func position(): Int64 { return source.position() }
    public func finalize(): Array<UInt8> { return source.finalize() }
}

/** Validates one CRC-32/ISCSI message and exposes the payload as a slice source. */
public class Crc32DeserializeFlavor <: DeserializeFlavor {
    private let source: SliceDeserializeFlavor

    public init(message: Array<UInt8>) {
        source = SliceDeserializeFlavor(stripAndVerifyCrc32c(message))
    }

    public func pop(): UInt8 { return source.pop() }
    public func tryTake(count: Int64): Array<UInt8> { return source.tryTake(count) }
    public func sizeHint(): Option<Int64> { return source.sizeHint() }
    public func position(): Int64 { return source.position() }
    public func finalize(): Array<UInt8> { return source.finalize() }
}

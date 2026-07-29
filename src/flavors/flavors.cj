package postcard4cj.flavors

import postcard4cj.core.*
import std.collection.*

/**
 * Cangjie-native equivalent of Postcard's serialization Flavor abstraction.
 *
 * Flavors may store bytes directly or transform them before passing them to an
 * inner flavor. All failures use the stable Postcard error model.
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

    public func tryPush(_: UInt8): Unit {
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

private func stripAndVerifyCrc32(input: Array<UInt8>, digest: Crc32Digest): Array<UInt8> {
    if (input.size < 4) {
        throw postcardException(PostcardErrorKind.DeserializeBadCrc)
    }
    let payloadEnd = input.size - 4
    let payload = input[..payloadEnd]
    for (byte in payload) {
        digest.updateByte(byte)
    }
    let expected = digest.checksum()
    let actual = UInt32(input[payloadEnd]) |
        (UInt32(input[payloadEnd + 1]) << 8) |
        (UInt32(input[payloadEnd + 2]) << 16) |
        (UInt32(input[payloadEnd + 3]) << 24)
    if (actual != expected) {
        throw postcardException(PostcardErrorKind.DeserializeBadCrc)
    }
    return payload
}

/**
 * Incremental COBS middleware.
 *
 * The previous implementation retained the complete raw payload and allocated
 * another complete encoded payload during finalization. This implementation
 * stores already encoded blocks and a fixed 254-byte pending segment, so
 * finalization writes directly into the inner flavor without a second complete
 * message allocation. `snapshot()` remains non-mutating and composable.
 */
public class CobsSerializeFlavor <: SerializeFlavor {
    private let inner: SerializeFlavor
    private let encoded: ArrayList<UInt8>
    private let segment: Array<UInt8>
    private var segmentLength: Int64
    private var rawPosition: Int64

    public init(inner: SerializeFlavor) {
        this.inner = inner
        encoded = ArrayList<UInt8>()
        segment = Array<UInt8>(254, repeat: 0u8)
        segmentLength = 0
        rawPosition = 0
    }

    private func appendPendingBlock(output: ArrayList<UInt8>): Unit {
        output.add(UInt8(segmentLength + 1))
        var index = 0i64
        while (index < segmentLength) {
            output.add(segment[index])
            index++
        }
    }

    private func flushPendingBlock(): Unit {
        appendPendingBlock(encoded)
        segmentLength = 0
    }

    public func tryPush(data: UInt8): Unit {
        rawPosition++
        if (data == 0u8) {
            flushPendingBlock()
            return
        }

        segment[segmentLength] = data
        segmentLength++
        if (segmentLength == 254) {
            encoded.add(0xffu8)
            var index = 0i64
            while (index < 254) {
                encoded.add(segment[index])
                index++
            }
            segmentLength = 0
        }
    }

    public func tryExtend(data: Array<UInt8>): Unit {
        for (byte in data) {
            tryPush(byte)
        }
    }

    public func position(): Int64 {
        return rawPosition
    }

    public func snapshot(): Array<UInt8> {
        let output = ArrayList<UInt8>(encoded.size + segmentLength + 2)
        for (byte in encoded) {
            output.add(byte)
        }
        appendPendingBlock(output)
        output.add(0u8)
        return output.toArray()
    }

    public func finalize(): Array<UInt8> {
        flushPendingBlock()
        encoded.add(0u8)
        for (byte in encoded) {
            inner.tryPush(byte)
        }
        return inner.finalize()
    }
}

/**
 * Incremental CRC-32/ISCSI middleware.
 *
 * The checksum is updated as bytes arrive. Raw bytes are retained only to
 * preserve arbitrary Flavor composition and non-mutating snapshot semantics;
 * finalization forwards them directly and does not allocate a second complete
 * payload-plus-checksum array.
 */
public class Crc32SerializeFlavor <: SerializeFlavor {
    private let inner: SerializeFlavor
    private let raw: ArrayList<UInt8>
    private let digest: Crc32Digest

    public init(inner: SerializeFlavor) {
        this.inner = inner
        digest = crc32IscsiDigest()
        raw = ArrayList<UInt8>()
    }

    public init(inner: SerializeFlavor, digest: Crc32Digest) {
        this.inner = inner
        this.digest = digest
        raw = ArrayList<UInt8>()
    }

    public func tryPush(data: UInt8): Unit {
        raw.add(data)
        digest.updateByte(data)
    }

    public func tryExtend(data: Array<UInt8>): Unit {
        for (byte in data) {
            tryPush(byte)
        }
    }

    public func position(): Int64 {
        return raw.size
    }

    private func checksum(): UInt32 {
        return digest.checksum()
    }

    private func appendChecksum(output: ArrayList<UInt8>): Unit {
        let value = checksum()
        output.add(UInt8(value & 0xffu32))
        output.add(UInt8((value >> 8) & 0xffu32))
        output.add(UInt8((value >> 16) & 0xffu32))
        output.add(UInt8((value >> 24) & 0xffu32))
    }

    public func snapshot(): Array<UInt8> {
        let output = ArrayList<UInt8>(raw.size + 4)
        for (byte in raw) {
            output.add(byte)
        }
        appendChecksum(output)
        return output.toArray()
    }

    public func finalize(): Array<UInt8> {
        for (byte in raw) {
            inner.tryPush(byte)
        }
        let value = checksum()
        inner.tryPush(UInt8(value & 0xffu32))
        inner.tryPush(UInt8((value >> 8) & 0xffu32))
        inner.tryPush(UInt8((value >> 16) & 0xffu32))
        inner.tryPush(UInt8((value >> 24) & 0xffu32))
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
        source = SliceDeserializeFlavor(
            stripAndVerifyCrc32(message, crc32IscsiDigest())
        )
    }

    public init(message: Array<UInt8>, digest: Crc32Digest) {
        source = SliceDeserializeFlavor(stripAndVerifyCrc32(message, digest))
    }

    public func pop(): UInt8 { return source.pop() }
    public func tryTake(count: Int64): Array<UInt8> { return source.tryTake(count) }
    public func sizeHint(): Option<Int64> { return source.sizeHint() }
    public func position(): Int64 { return source.position() }
    public func finalize(): Array<UInt8> { return source.finalize() }
}

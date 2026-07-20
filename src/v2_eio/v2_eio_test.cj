package postcard4cj.v2_eio

import postcard4cj.serde_model.*
import postcard4cj.v2.DeserializerErrorKind
import postcard4cj.v2.DeserializerException
import postcard4cj.v2.SerializerErrorKind
import postcard4cj.v2.SerializerException
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

private class MemoryWriter <: ByteWriter {
    private let bytes: ArrayList<UInt8>
    private var flushes: Int64

    public init() {
        bytes = ArrayList<UInt8>()
        flushes = 0
    }

    public func writeAll(data: Array<UInt8>): Unit {
        for (byte in data) {
            bytes.add(byte)
        }
    }

    public func flush(): Unit {
        flushes++
    }

    public func toArray(): Array<UInt8> {
        return bytes.toArray()
    }

    public func flushCount(): Int64 {
        return flushes
    }
}

private class FailingWriter <: ByteWriter {
    public func writeAll(data: Array<UInt8>): Unit {
        throw IllegalStateException("write failure")
    }

    public func flush(): Unit {}
}

private class MemoryReader <: ByteReader {
    private let input: Array<UInt8>
    private var cursor: Int64

    public init(input: Array<UInt8>) {
        this.input = input
        cursor = 0
    }

    public func readExact(count: Int64): Array<UInt8> {
        if (count < 0 || count > input.size - cursor) {
            throw IllegalStateException("unexpected end")
        }
        let end = cursor + count
        let output = input[cursor..end]
        cursor = end
        return output
    }

    public func position(): Int64 {
        return cursor
    }
}

public struct EioRecord <: PostcardSerialize & PostcardDeserialize<EioRecord> {
    public let id: UInt32
    public let name: String
    public let active: Bool

    public init(id: UInt32, name: String, active: Bool) {
        this.id = id
        this.name = name
        this.active = active
    }

    public func serialize(serializer: Serializer): Unit {
        serializer.serializeUInt32(id)
        serializer.serializeString(name)
        serializer.serializeBool(active)
    }

    public static func deserialize(deserializer: Deserializer): EioRecord {
        return EioRecord(
            deserializer.deserializeUInt32(),
            deserializer.deserializeString(),
            deserializer.deserializeBool()
        )
    }
}

@Test
public class PostcardV2EioTest {
    @TestCase
    public func writerStreamsAndFlushesSerializedBytes(): Unit {
        let writer = MemoryWriter()
        toEioV2<EioRecord>(EioRecord(300u32, "Hi", true), writer)
        @Assert(
            writer.toArray(),
            [0xacu8, 0x02u8, 0x02u8, 0x48u8, 0x69u8, 0x01u8]
        )
        @Assert(writer.flushCount(), 1)
    }

    @TestCase
    public func readerReturnsStateAndUnusedScratch(): Unit {
        let reader = MemoryReader([
            0xacu8, 0x02u8, 0x02u8, 0x48u8, 0x69u8, 0x01u8, 0xffu8
        ])
        let scratch = Array<UInt8>(8, repeat: 0u8)
        let result = fromEioV2<EioRecord>(reader, scratch)

        @Assert(result.value.id, 300u32)
        @Assert(result.value.name, "Hi")
        @Assert(result.value.active, true)
        @Assert(reader.position(), 6)
        @Assert(result.unusedScratch.size, 6)
    }

    @TestCase
    public func temporaryBufferExhaustionMapsToPopError(): Unit {
        let reader = MemoryReader([0x01u8, 0x02u8, 0x48u8, 0x69u8, 0x01u8])
        try {
            fromEioV2<EioRecord>(reader, Array<UInt8>(1, repeat: 0u8))
            throw IllegalStateException("Expected EIO deserialization error")
        } catch (error: DeserializerException) {
            match (error.kind) {
                case DeserializerErrorKind.PopError => ()
                case _ => throw IllegalStateException("Wrong EIO error category")
            }
        }
    }

    @TestCase
    public func readerUnexpectedEndMapsToPopError(): Unit {
        let reader = MemoryReader([0x80u8])
        try {
            fromEioV2<EioRecord>(reader, Array<UInt8>(8, repeat: 0u8))
            throw IllegalStateException("Expected EIO deserialization error")
        } catch (error: DeserializerException) {
            match (error.kind) {
                case DeserializerErrorKind.PopError => ()
                case _ => throw IllegalStateException("Wrong EIO error category")
            }
        }
    }

    @TestCase
    public func writerFailureMapsToPushError(): Unit {
        try {
            toEioV2<EioRecord>(EioRecord(1u32, "x", true), FailingWriter())
            throw IllegalStateException("Expected EIO serialization error")
        } catch (error: SerializerException) {
            match (error.kind) {
                case SerializerErrorKind.PushError => ()
                case _ => throw IllegalStateException("Wrong EIO serializer error")
            }
        }
    }
}

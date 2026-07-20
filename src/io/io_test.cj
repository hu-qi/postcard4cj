package postcard4cj.io

import postcard4cj.core.*
import postcard4cj.serde_model.*
import postcard4cj.v2_eio.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

private class LegacyWriter <: ByteWriter {
    private let bytes: ArrayList<UInt8>

    public init() {
        bytes = ArrayList<UInt8>()
    }

    public func writeAll(data: Array<UInt8>): Unit {
        for (byte in data) { bytes.add(byte) }
    }

    public func flush(): Unit {}

    public func toArray(): Array<UInt8> { return bytes.toArray() }
}

private class LegacyReader <: ByteReader {
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
}

public struct LegacyIoPacket <: PostcardSerialize & PostcardDeserialize<LegacyIoPacket> {
    public let id: UInt16
    public let label: String

    public init(id: UInt16, label: String) {
        this.id = id
        this.label = label
    }

    public func serialize(serializer: Serializer): Unit {
        serializer.serializeUInt16(id)
        serializer.serializeString(label)
    }

    public static func deserialize(deserializer: Deserializer): LegacyIoPacket {
        return LegacyIoPacket(
            deserializer.deserializeUInt16(),
            deserializer.deserializeString()
        )
    }
}

@Test
public class LegacyIoTest {
    @TestCase
    public func legacyWriterUsesPostcardWireFormat(): Unit {
        let writer = LegacyWriter()
        toIo<LegacyIoPacket>(LegacyIoPacket(128u16, "Hi"), writer)
        @Assert(writer.toArray(), [0x80u8, 0x01u8, 0x02u8, 0x48u8, 0x69u8])
    }

    @TestCase
    public func legacyReaderReturnsTypedValue(): Unit {
        let result = fromIo<LegacyIoPacket>(
            LegacyReader([0x80u8, 0x01u8, 0x02u8, 0x48u8, 0x69u8]),
            Array<UInt8>(8, repeat: 0u8)
        )
        @Assert(result.value.id, 128u16)
        @Assert(result.value.label, "Hi")
        @Assert(result.unusedScratch.size, 6)
    }

    @TestCase
    public func legacyReaderMapsUnexpectedEnd(): Unit {
        try {
            fromIo<LegacyIoPacket>(
                LegacyReader([0x80u8]),
                Array<UInt8>(8, repeat: 0u8)
            )
            throw IllegalStateException("Expected legacy IO error")
        } catch (error: PostcardException) {
            match (error.kind) {
                case PostcardErrorKind.DeserializeUnexpectedEnd => ()
                case _ => throw IllegalStateException("Wrong legacy IO error")
            }
        }
    }
}

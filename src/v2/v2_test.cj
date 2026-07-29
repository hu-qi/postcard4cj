package postcard4cj.v2

import postcard4cj.flavors.*
import postcard4cj.serde_model.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

private class V2ListSink <: ByteExtendSink {
    private let bytes: ArrayList<UInt8>

    public init(prefix: Array<UInt8>) {
        bytes = ArrayList<UInt8>()
        for (byte in prefix) {
            bytes.add(byte)
        }
    }

    public func appendBytes(data: Array<UInt8>): Unit {
        for (byte in data) {
            bytes.add(byte)
        }
    }

    public func toArray(): Array<UInt8> {
        return bytes.toArray()
    }
}

public struct V2Record <: PostcardSerialize & PostcardDeserialize<V2Record> {
    public let id: UInt32
    public let delta: Int32
    public let active: Bool
    public let name: String

    public init(id: UInt32, delta: Int32, active: Bool, name: String) {
        this.id = id
        this.delta = delta
        this.active = active
        this.name = name
    }

    public func serialize(serializer: Serializer): Unit {
        serializer.beginStruct("V2Record", 4)
        serializer.serializeUInt32(id)
        serializer.serializeInt32(delta)
        serializer.serializeBool(active)
        serializer.serializeString(name)
    }

    public static func deserialize(deserializer: Deserializer): V2Record {
        deserializer.beginStruct("V2Record", 4)
        return V2Record(
            deserializer.deserializeUInt32(),
            deserializer.deserializeInt32(),
            deserializer.deserializeBool(),
            deserializer.deserializeString()
        )
    }
}

public struct V2Bool <: PostcardDeserialize<V2Bool> {
    public let value: Bool

    public init(value: Bool) {
        this.value = value
    }

    public static func deserialize(deserializer: Deserializer): V2Bool {
        return V2Bool(deserializer.deserializeBool())
    }
}

public struct V2UInt32 <: PostcardDeserialize<V2UInt32> {
    public let value: UInt32

    public init(value: UInt32) {
        this.value = value
    }

    public static func deserialize(deserializer: Deserializer): V2UInt32 {
        return V2UInt32(deserializer.deserializeUInt32())
    }
}

public struct V2ByteSequence <: PostcardDeserialize<V2ByteSequence> {
    public let values: Array<UInt8>

    public init(values: Array<UInt8>) {
        this.values = values
    }

    public static func deserialize(deserializer: Deserializer): V2ByteSequence {
        return V2ByteSequence(
            deserializer.deserializeSequence<UInt8>({=> deserializer.deserializeUInt8()})
        )
    }
}

@Test
public class PostcardV2ApiTest {
    private let value = V2Record(42u32, -1i32, true, "Hi")
    private let expected: Array<UInt8> = [
        0x2au8, 0x01u8, 0x01u8, 0x02u8, 0x48u8, 0x69u8
    ]

    @TestCase
    public func toVecMatchesPostcardOneWireFormat(): Unit {
        @Assert(toVecV2<V2Record>(value), expected)
    }

    @TestCase
    public func fixedSliceAndSerializedSizeAgree(): Unit {
        let buffer = Array<UInt8>(10, repeat: 0xeeu8)
        let used = toSliceV2<V2Record>(value, buffer)
        @Assert(used, expected.size)
        @Assert(buffer[..used], expected)
        @Assert(serializedSizeV2<V2Record>(value), expected.size)
    }

    @TestCase
    public func extendStreamsToExistingDestination(): Unit {
        let sink = V2ListSink([0xaau8])
        toExtendV2<V2Record>(value, sink)
        @Assert(
            sink.toArray(),
            [0xaau8, 0x2au8, 0x01u8, 0x01u8, 0x02u8, 0x48u8, 0x69u8]
        )
    }

    @TestCase
    public func fromBytesIgnoresTrailingDataLikePostcard2(): Unit {
        let input: Array<UInt8> = [
            0x2au8, 0x01u8, 0x01u8, 0x02u8, 0x48u8, 0x69u8, 0xffu8
        ]
        let decoded = fromBytesV2<V2Record>(input)
        @Assert(decoded.id, 42u32)
        @Assert(decoded.name, "Hi")
    }

    @TestCase
    public func takeFromBytesReturnsRemainder(): Unit {
        let input: Array<UInt8> = [
            0x2au8, 0x01u8, 0x01u8, 0x02u8, 0x48u8, 0x69u8, 0xaau8
        ]
        let decoded = takeFromBytesV2<V2Record>(input)
        @Assert(decoded[0].active, true)
        @Assert(decoded[1], [0xaau8])
    }
}

@Test
public class PostcardV2ErrorTest {
    @TestCase
    public func fixedBufferOverflowMapsToPushError(): Unit {
        try {
            toSliceV2<V2Record>(
                V2Record(42u32, -1i32, true, "Hi"),
                Array<UInt8>(2, repeat: 0u8)
            )
            throw IllegalStateException("Expected SerializerException")
        } catch (error: SerializerException) {
            match (error.kind) {
                case SerializerErrorKind.PushError => ()
                case _ => throw IllegalStateException("Wrong serializer error")
            }
        }
    }

    @TestCase
    public func badBoolMapsToBadBool(): Unit {
        try {
            fromBytesV2<V2Bool>([0x02u8])
            throw IllegalStateException("Expected DeserializerException")
        } catch (error: DeserializerException) {
            match (error.kind) {
                case DeserializerErrorKind.BadBool => ()
                case _ => throw IllegalStateException("Wrong bool error")
            }
        }
    }

    @TestCase
    public func badVarintMapsToBadVarint(): Unit {
        try {
            fromBytesV2<V2UInt32>([0xffu8, 0xffu8, 0xffu8, 0xffu8, 0x1fu8])
            throw IllegalStateException("Expected DeserializerException")
        } catch (error: DeserializerException) {
            match (error.kind) {
                case DeserializerErrorKind.BadVarint => ()
                case _ => throw IllegalStateException("Wrong varint error")
            }
        }
    }

    @TestCase
    public func truncatedInputMapsToPopError(): Unit {
        try {
            fromBytesV2<V2UInt32>([0x80u8])
            throw IllegalStateException("Expected DeserializerException")
        } catch (error: DeserializerException) {
            match (error.kind) {
                case DeserializerErrorKind.PopError => ()
                case _ => throw IllegalStateException("Wrong pop error")
            }
        }
    }

    @TestCase
    public func untrustedSequenceLengthMapsToPopErrorWithoutEagerAllocation(): Unit {
        try {
            fromBytesV2<V2ByteSequence>([
                0xffu8, 0xffu8, 0xffu8, 0xffu8, 0x0fu8
            ])
            throw IllegalStateException("Expected DeserializerException")
        } catch (error: DeserializerException) {
            match (error.kind) {
                case DeserializerErrorKind.PopError => ()
                case _ => throw IllegalStateException("Wrong sequence error")
            }
        }
    }
}

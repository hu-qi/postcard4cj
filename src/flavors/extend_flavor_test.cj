package postcard4cj.flavors

import postcard4cj.serde_model.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

private class ArrayListSink <: ByteExtendSink {
    private let values: ArrayList<UInt8>

    public init(prefix: Array<UInt8>) {
        values = ArrayList<UInt8>()
        for (byte in prefix) {
            values.add(byte)
        }
    }

    public func extend(data: Array<UInt8>): Unit {
        for (byte in data) {
            values.add(byte)
        }
    }

    public func toArray(): Array<UInt8> {
        return values.toArray()
    }
}

private class RejectingSink <: ByteExtendSink {
    public func extend(data: Array<UInt8>): Unit {
        throw IllegalStateException("sink rejected data")
    }
}

public struct ExtendPacket <: PostcardSerialize {
    public let id: UInt32
    public let enabled: Bool

    public init(id: UInt32, enabled: Bool) {
        this.id = id
        this.enabled = enabled
    }

    public func serialize(serializer: Serializer): Unit {
        serializer.serializeUInt32(id)
        serializer.serializeBool(enabled)
    }
}

@Test
public class ExtendSerializeFlavorTest {
    @TestCase
    public func serializerStreamsIntoExistingSink(): Unit {
        let sink = ArrayListSink([0xaau8])
        let flavor = ExtendSerializeFlavor(sink)
        let serializer = Serializer(flavor)
        ExtendPacket(300u32, true).serialize(serializer)
        serializer.finalize()

        @Assert(flavor.position(), 3)
        @Assert(sink.toArray(), [0xaau8, 0xacu8, 0x02u8, 0x01u8])
    }

    @TestCase
    public func sinkFailureUsesPostcardBufferError(): Unit {
        let serializer = Serializer(ExtendSerializeFlavor(RejectingSink()))
        @AssertThrows[Exception](serializer.serializeUInt32(300u32))
    }
}

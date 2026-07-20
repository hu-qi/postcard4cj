package postcard4cj.v2_fixed

import postcard4cj.serde_model.*
import postcard4cj.v2.*
import std.unittest.*
import std.unittest.testmacro.*

public struct FixedPacket <: PostcardSerialize {
    public let id: UInt32
    public let active: Bool

    public init(id: UInt32, active: Bool) {
        this.id = id
        this.active = active
    }

    public func serialize(serializer: Serializer): Unit {
        serializer.serializeUInt32(id)
        serializer.serializeBool(active)
    }
}

@Test
public class FixedByteVecTest {
    @TestCase
    public func pushAppendAndMutationRespectUsedLength(): Unit {
        let value = FixedByteVec(5)
        value.push(1u8)
        value.appendBytes([2u8, 3u8])
        @Assert(value.size(), 3)
        @Assert(value.remaining(), 2)
        @Assert(value.toArray(), [1u8, 2u8, 3u8])
        value.set(1, 9u8)
        @Assert(value.get(1), 9u8)
    }

    @TestCase
    public func exactCapacitySerializesPostcardBytes(): Unit {
        let value = toFixedVecV2<FixedPacket>(FixedPacket(300u32, true), 3)
        @Assert(value.capacity(), 3)
        @Assert(value.size(), 3)
        @Assert(value.toArray(), [0xacu8, 0x02u8, 0x01u8])
    }

    @TestCase
    public func largerCapacityKeepsLogicalLength(): Unit {
        let value = toFixedVecV2<FixedPacket>(FixedPacket(1u32, false), 8)
        @Assert(value.size(), 2)
        @Assert(value.remaining(), 6)
        @Assert(value.toArray(), [0x01u8, 0x00u8])
    }

    @TestCase
    public func capacityOverflowMapsToPushError(): Unit {
        try {
            toFixedVecV2<FixedPacket>(FixedPacket(300u32, true), 2)
            throw IllegalStateException("Expected fixed-capacity error")
        } catch (error: SerializerException) {
            match (error.kind) {
                case SerializerErrorKind.PushError => ()
                case _ => throw IllegalStateException("Wrong fixed error category")
            }
        }
    }

    @TestCase
    public func directOverflowFailsImmediately(): Unit {
        let value = FixedByteVec(1)
        value.push(1u8)
        @AssertThrows[Exception](value.push(2u8))
    }
}

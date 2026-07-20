package postcard4cj.accumulator

import postcard4cj.flavors.*
import postcard4cj.serde_model.*
import std.unittest.*
import std.unittest.testmacro.*

public struct AccRecord <: PostcardSerialize & PostcardDeserialize<AccRecord> {
    public let id: UInt32
    public let enabled: Bool

    public init(id: UInt32, enabled: Bool) {
        this.id = id
        this.enabled = enabled
    }

    public func serialize(serializer: Serializer): Unit {
        serializer.beginStruct("AccRecord", 2)
        serializer.serializeUInt32(id)
        serializer.serializeBool(enabled)
    }

    public static func deserialize(deserializer: Deserializer): AccRecord {
        deserializer.beginStruct("AccRecord", 2)
        return AccRecord(
            deserializer.deserializeUInt32(),
            deserializer.deserializeBool()
        )
    }
}

private func frame(value: AccRecord): Array<UInt8> {
    return serializeWithFlavor<AccRecord>(
        value,
        CobsSerializeFlavor(ArraySerializeFlavor())
    )
}

@Test
public class CobsAccumulatorTest {
    @TestCase
    public func chunkedFrameIsConsumedThenDecoded(): Unit {
        let encoded = frame(AccRecord(300u32, true))
        let split = 2i64
        let accumulator = CobsAccumulator(32)

        match (accumulator.feed<AccRecord>(encoded[..split])) {
            case FeedResult<AccRecord>.Consumed => ()
            case _ => throw IllegalStateException("Expected pending accumulator")
        }
        @Assert(accumulator.pending(), split)

        match (accumulator.feed<AccRecord>(encoded[split..encoded.size])) {
            case FeedResult<AccRecord>.Success(value, remaining) =>
                @Assert(value.id, 300u32)
                @Assert(value.enabled, true)
                @Assert(remaining, [])
            case _ => throw IllegalStateException("Expected decoded frame")
        }
        @Assert(accumulator.pending(), 0)
    }

    @TestCase
    public func multipleFramesReturnRemainder(): Unit {
        let first = frame(AccRecord(10u32, true))
        let second = frame(AccRecord(20u32, false))
        let input = Array<UInt8>(first.size + second.size, repeat: 0u8)
        var cursor = 0i64
        for (byte in first) {
            input[cursor] = byte
            cursor++
        }
        for (byte in second) {
            input[cursor] = byte
            cursor++
        }

        let accumulator = CobsAccumulator(32)
        let remainder = match (accumulator.feed<AccRecord>(input)) {
            case FeedResult<AccRecord>.Success(value, remaining) =>
                @Assert(value.id, 10u32)
                remaining
            case _ => throw IllegalStateException("Expected first frame")
        }

        match (accumulator.feed<AccRecord>(remainder)) {
            case FeedResult<AccRecord>.Success(value, remaining) =>
                @Assert(value.id, 20u32)
                @Assert(value.enabled, false)
                @Assert(remaining, [])
            case _ => throw IllegalStateException("Expected second frame")
        }
    }

    @TestCase
    public func overfullResetsAndReturnsUnconsumedInput(): Unit {
        let accumulator = CobsAccumulator(3)
        match (accumulator.feed<AccRecord>([1u8, 2u8, 3u8, 4u8, 5u8])) {
            case FeedResult<AccRecord>.OverFull(remaining) =>
                @Assert(remaining, [4u8, 5u8])
            case _ => throw IllegalStateException("Expected overflow")
        }
        @Assert(accumulator.pending(), 0)
    }

    @TestCase
    public func malformedFrameReturnsDeserError(): Unit {
        let accumulator = CobsAccumulator(16)
        match (accumulator.feed<AccRecord>([0x02u8, 0xffu8, 0x00u8, 0xaau8])) {
            case FeedResult<AccRecord>.DeserError(remaining) =>
                @Assert(remaining, [0xaau8])
            case _ => throw IllegalStateException("Expected deserialization error")
        }
    }

    @TestCase
    public func emptyInputIsConsumed(): Unit {
        let accumulator = CobsAccumulator(16)
        match (accumulator.feed<AccRecord>([])) {
            case FeedResult<AccRecord>.Consumed => ()
            case _ => throw IllegalStateException("Expected consumed")
        }
    }
}

package postcard4cj

import std.unittest.*
import std.unittest.testmacro.*

public struct Telemetry <: PostcardEncode & PostcardDecode<Telemetry> {
    public let id: UInt32
    public let temperature: Float32
    public let note: Option<String>
    public let samples: Array<Int16>

    public init(id: UInt32, temperature: Float32, note: Option<String>, samples: Array<Int16>) {
        this.id = id
        this.temperature = temperature
        this.note = note
        this.samples = samples
    }

    public func encode(encoder: PostcardEncoder): Unit {
        encoder.writeUInt32(id)
        encoder.writeFloat32(temperature)
        encoder.writeOption<String>(note, {value: String => encoder.writeString(value)})
        encoder.writeSequence<Int16>(samples, {value: Int16 => encoder.writeInt16(value)})
    }

    public static func decode(decoder: PostcardDecoder): Telemetry {
        return Telemetry(decoder.readUInt32(), decoder.readFloat32(), decoder.readOption<String>({=> decoder.readString()}), decoder.readSequence<Int16>({=> decoder.readInt16()}))
    }
}

@Test
public class PostcardFloatTest {
    @TestCase
    public func littleEndianFloatVectors(): Unit {
        let encoder = PostcardEncoder()
        encoder.writeFloat32(12.5f32)
        encoder.writeFloat64(12.5f64)
        @Assert(encoder.toArray(), [0x00u8,0x00u8,0x48u8,0x41u8,0x00u8,0x00u8,0x00u8,0x00u8,0x00u8,0x00u8,0x29u8,0x40u8])
        let decoder = PostcardDecoder(encoder.toArray())
        @Assert(decoder.readFloat32(), 12.5f32)
        @Assert(decoder.readFloat64(), 12.5f64)
        @Assert(decoder.remaining(), 0)
    }
}

@Test
public class PostcardOptionAndSequenceTest {
    @TestCase
    public func optionVectors(): Unit {
        let absent: Option<Int32> = None
        let encoder = PostcardEncoder()
        encoder.writeOption<Int32>(absent, {value: Int32 => encoder.writeInt32(value)})
        encoder.writeOption<Int32>(Some(-1i32), {value: Int32 => encoder.writeInt32(value)})
        @Assert(encoder.toArray(), [0u8,1u8,1u8])
        let decoder = PostcardDecoder(encoder.toArray())
        @Assert(decoder.readOption<Int32>({=> decoder.readInt32()}), absent)
        @Assert(decoder.readOption<Int32>({=> decoder.readInt32()}), Some(-1i32))
    }

    @TestCase
    public func sequenceVector(): Unit {
        let encoder = PostcardEncoder()
        encoder.writeSequence<UInt16>([1u16,128u16], {value: UInt16 => encoder.writeUInt16(value)})
        @Assert(encoder.toArray(), [2u8,1u8,0x80u8,0x01u8])
        let decoder = PostcardDecoder(encoder.toArray())
        @Assert(decoder.readSequence<UInt16>({=> decoder.readUInt16()}), [1u16,128u16])
    }

    @TestCase
    public func untrustedSequenceLengthDoesNotPreallocateWireCount(): Unit {
        let encoder = PostcardEncoder()
        encoder.writeSequenceLength(1_000_000_000i64)
        let decoder = PostcardDecoder(encoder.toArray())
        @AssertThrows[Exception](decoder.readSequence<UInt8>({=> decoder.readUInt8()}))
    }
}

@Test
public class PostcardTypedCodecTest {
    @TestCase
    public func rustCompatibleTelemetryVector(): Unit {
        let expected: Array<UInt8> = [0xacu8,0x02u8,0x00u8,0x00u8,0x48u8,0x41u8,0x01u8,0x02u8,0x6fu8,0x6bu8,0x04u8,0x01u8,0x00u8,0x02u8,0x80u8,0x02u8]
        let telemetry = Telemetry(300u32,12.5f32,Some("ok"),[-1i16,0i16,1i16,128i16])
        @Assert(toBytes<Telemetry>(telemetry), expected)
        let decoded = fromBytes<Telemetry>(expected)
        @Assert(decoded.id, 300u32)
        @Assert(decoded.temperature, 12.5f32)
        @Assert(decoded.note, Some("ok"))
        @Assert(decoded.samples, [-1i16,0i16,1i16,128i16])
    }

    @TestCase
    public func takeFromConcatenatedInput(): Unit {
        let input: Array<UInt8> = [0xacu8,0x02u8,0x00u8,0x00u8,0x48u8,0x41u8,0x01u8,0x02u8,0x6fu8,0x6bu8,0x04u8,0x01u8,0x00u8,0x02u8,0x80u8,0x02u8,0xffu8]
        let decoded = takeFromBytes<Telemetry>(input)
        @Assert(decoded[0].id, 300u32)
        @Assert(decoded[1], 16)
    }
}

package postcard4cj.compatibility

import postcard4cj.*
import postcard4cj.postcard_macro.*
import std.math.numeric.*
import std.unittest.*
import std.unittest.testmacro.*

public struct CompatibilityRecord <: PostcardEncode & PostcardDecode<CompatibilityRecord> {
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

    public func encode(encoder: PostcardEncoder): Unit {
        encoder.writeUInt32(id)
        encoder.writeInt32(delta)
        encoder.writeBool(active)
        encoder.writeString(name)
    }

    public static func decode(decoder: PostcardDecoder): CompatibilityRecord {
        return CompatibilityRecord(
            decoder.readUInt32(),
            decoder.readInt32(),
            decoder.readBool(),
            decoder.readString()
        )
    }
}

public struct CompatibilityTelemetry <: PostcardEncode & PostcardDecode<CompatibilityTelemetry> {
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

    public static func decode(decoder: PostcardDecoder): CompatibilityTelemetry {
        return CompatibilityTelemetry(
            decoder.readUInt32(),
            decoder.readFloat32(),
            decoder.readOption<String>({=> decoder.readString()}),
            decoder.readSequence<Int16>({=> decoder.readInt16()})
        )
    }
}

@Postcard
public struct CompatibilityMacroRecord {
    public let id: UInt32
    public let delta: Int32
    public let note: Option<String>
    public let values: Array<UInt16>

    public init(id: UInt32, delta: Int32, note: Option<String>, values: Array<UInt16>) {
        this.id = id
        this.delta = delta
        this.note = note
        this.values = values
    }
}

@Postcard
public enum CompatibilityMacroCommand {
    | Ping
    | SetSpeed(UInt16)
    | Rename(String, Bool)
}

@Test
public class PureCangjieCompatibilityVectorsTest {
    @TestCase
    public func recordVector(): Unit {
        let value = CompatibilityRecord(42u32, -1i32, true, "Hi")
        let expected: Array<UInt8> = [0x2au8, 0x01u8, 0x01u8, 0x02u8, 0x48u8, 0x69u8]
        @Assert(toBytes<CompatibilityRecord>(value), expected)
        let decoded = fromBytes<CompatibilityRecord>(expected)
        @Assert(decoded.id, value.id)
        @Assert(decoded.delta, value.delta)
        @Assert(decoded.active, value.active)
        @Assert(decoded.name, value.name)
    }

    @TestCase
    public func telemetryAndFramingVectors(): Unit {
        let value = CompatibilityTelemetry(300u32, 12.5f32, Some("ok"), [-1i16, 0i16, 1i16, 128i16])
        let plain: Array<UInt8> = [
            0xacu8, 0x02u8, 0x00u8, 0x00u8, 0x48u8, 0x41u8, 0x01u8, 0x02u8,
            0x6fu8, 0x6bu8, 0x04u8, 0x01u8, 0x00u8, 0x02u8, 0x80u8, 0x02u8
        ]
        let cobs: Array<UInt8> = [
            0x03u8, 0xacu8, 0x02u8, 0x01u8, 0x09u8, 0x48u8, 0x41u8, 0x01u8,
            0x02u8, 0x6fu8, 0x6bu8, 0x04u8, 0x01u8, 0x04u8, 0x02u8, 0x80u8,
            0x02u8, 0x00u8
        ]
        let crc: Array<UInt8> = [
            0xacu8, 0x02u8, 0x00u8, 0x00u8, 0x48u8, 0x41u8, 0x01u8, 0x02u8,
            0x6fu8, 0x6bu8, 0x04u8, 0x01u8, 0x00u8, 0x02u8, 0x80u8, 0x02u8,
            0xaeu8, 0xb6u8, 0xf9u8, 0xb6u8
        ]

        @Assert(toBytes<CompatibilityTelemetry>(value), plain)
        @Assert(toBytesCobs<CompatibilityTelemetry>(value), cobs)
        @Assert(toBytesCrc32Iscsi<CompatibilityTelemetry>(value), crc)
        @Assert(fromBytesCobs<CompatibilityTelemetry>(cobs).samples, value.samples)
        @Assert(fromBytesCrc32Iscsi<CompatibilityTelemetry>(crc).note, value.note)
    }

    @TestCase
    public func compoundVector(): Unit {
        let encoder = PostcardEncoder()
        encoder.writeRune(r'爱')
        encoder.writeUnit()
        encoder.writeTuple2<UInt8, Int16>(
            (7u8, -1i16),
            {value: UInt8 => encoder.writeUInt8(value)},
            {value: Int16 => encoder.writeInt16(value)}
        )
        encoder.writeMapEntries<UInt8, String>(
            [(1u8, "a"), (2u8, "b")],
            {key: UInt8 => encoder.writeUInt8(key)},
            {value: String => encoder.writeString(value)}
        )
        encoder.writeEnumIndex(1u32)
        encoder.writeUInt16(128u16)

        @Assert(
            encoder.toArray(),
            [
                0x03u8, 0xe7u8, 0x88u8, 0xb1u8, 0x07u8, 0x01u8, 0x02u8, 0x01u8,
                0x01u8, 0x61u8, 0x02u8, 0x01u8, 0x62u8, 0x01u8, 0x80u8, 0x01u8
            ]
        )
    }

    @TestCase
    public func wideIntegerVector(): Unit {
        let unsignedMaximum = BigInt.parse("340282366920938463463374607431768211455")
        let signedMinimum = BigInt.parse("-170141183460469231731687303715884105728")
        let signedSample = BigInt.parse("-19490127978232325886905073712831")
        let encoder = PostcardEncoder()
        encoder.writeUInt128(unsignedMaximum)
        encoder.writeInt128(signedMinimum)
        encoder.writeInt128(signedSample)

        @Assert(
            encoder.toArray(),
            [
                0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8,
                0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8,
                0xffu8, 0xffu8, 0x03u8,
                0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8,
                0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8, 0xffu8,
                0xffu8, 0xffu8, 0x03u8,
                0xfdu8, 0xfau8, 0xf5u8, 0xebu8, 0xf7u8, 0xffu8, 0xffu8, 0xffu8,
                0xffu8, 0xc3u8, 0xffu8, 0xffu8, 0xffu8, 0xffu8, 0x7au8
            ]
        )
    }

    @TestCase
    public func macroStructVector(): Unit {
        let value = CompatibilityMacroRecord(42u32, -1i32, Some("Hi"), [1u16, 128u16])
        let expected: Array<UInt8> = [
            0x2au8, 0x01u8, 0x01u8, 0x02u8, 0x48u8, 0x69u8, 0x02u8, 0x01u8,
            0x80u8, 0x01u8
        ]
        @Assert(toBytes<CompatibilityMacroRecord>(value), expected)
        @Assert(fromBytes<CompatibilityMacroRecord>(expected).values, value.values)
    }

    @TestCase
    public func macroEnumVectors(): Unit {
        @Assert(toBytes<CompatibilityMacroCommand>(CompatibilityMacroCommand.Ping), [0x00u8])
        @Assert(
            toBytes<CompatibilityMacroCommand>(CompatibilityMacroCommand.SetSpeed(128u16)),
            [0x01u8, 0x80u8, 0x01u8]
        )
        @Assert(
            toBytes<CompatibilityMacroCommand>(CompatibilityMacroCommand.Rename("Hi", true)),
            [0x02u8, 0x02u8, 0x48u8, 0x69u8, 0x01u8]
        )
    }
}

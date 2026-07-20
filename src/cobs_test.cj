package postcard4cj

import std.unittest.*
import std.unittest.testmacro.*

private func telemetryFrame(): Array<UInt8> {
    return [
        0x03u8, 0xacu8, 0x02u8,
        0x01u8,
        0x09u8, 0x48u8, 0x41u8, 0x01u8, 0x02u8,
        0x6fu8, 0x6bu8, 0x04u8, 0x01u8,
        0x04u8, 0x02u8, 0x80u8, 0x02u8,
        0x00u8
    ]
}

private func telemetryValueForCobs(): Telemetry {
    return Telemetry(
        300u32,
        12.5f32,
        Some("ok"),
        [-1i16, 0i16, 1i16, 128i16]
    )
}

@Test
public class PostcardCobsTest {
    @TestCase
    public func postcardFlavorExample(): Unit {
        let encoder = PostcardEncoder()
        encoder.writeBytes([0x01u8, 0x00u8, 0x20u8, 0x30u8])

        let frame = cobsEncode(encoder.toArray())
        @Assert(
            frame,
            [0x03u8, 0x04u8, 0x01u8, 0x03u8, 0x20u8, 0x30u8, 0x00u8]
        )
        @Assert(cobsDecode(frame), encoder.toArray())
    }

    @TestCase
    public func zerosAndTrailingZeroRoundTrip(): Unit {
        let raw: Array<UInt8> = [0x01u8, 0x00u8, 0x02u8, 0x00u8]
        let frame = cobsEncode(raw)
        @Assert(frame, [0x02u8, 0x01u8, 0x02u8, 0x02u8, 0x01u8, 0x00u8])
        @Assert(cobsDecode(frame), raw)
    }

    @TestCase
    public func exactMaximumBlockRoundTrip(): Unit {
        let raw = Array<UInt8>(254, repeat: 0x01u8)
        let frame = cobsEncode(raw)

        @Assert(frame.size, 257)
        @Assert(frame[0], 0xffu8)
        @Assert(frame[255], 0x01u8)
        @Assert(frame[256], 0x00u8)
        @Assert(cobsDecode(frame), raw)
    }

    @TestCase
    public func typedTelemetryFrameMatchesRustPostcard(): Unit {
        let expected = telemetryFrame()
        @Assert(toBytesCobs<Telemetry>(telemetryValueForCobs()), expected)

        let decoded = fromBytesCobs<Telemetry>(expected)
        @Assert(decoded.id, 300u32)
        @Assert(decoded.temperature, 12.5f32)
        @Assert(decoded.note, Some("ok"))
        @Assert(decoded.samples, [-1i16, 0i16, 1i16, 128i16])
    }

    @TestCase
    public func takeDecodesFirstFrameAndReturnsRemainder(): Unit {
        let frame = telemetryFrame()
        let input = Array<UInt8>(frame.size + 2, repeat: 0u8)
        var index = 0i64
        while (index < frame.size) {
            input[index] = frame[index]
            index++
        }
        input[index] = 0xaau8
        input[index + 1] = 0xbbu8

        let decoded = takeFromBytesCobs<Telemetry>(input)
        @Assert(decoded[0].id, 300u32)
        @Assert(decoded[1], [0xaau8, 0xbbu8])
    }

    @TestCase
    public func fixedBufferWritesFrameAndPreservesTail(): Unit {
        let expected = telemetryFrame()
        let buffer = Array<UInt8>(expected.size + 2, repeat: 0xeeu8)
        let used = encodeToCobs<Telemetry>(telemetryValueForCobs(), buffer)

        @Assert(used, expected.size)
        @Assert(buffer[..used], expected)
        @Assert(buffer[used..buffer.size], [0xeeu8, 0xeeu8])
    }

    @TestCase
    public func missingDelimiterIsRejected(): Unit {
        @AssertThrows[IllegalArgumentException](
            takeFromBytesCobs<Telemetry>(telemetryFrame()[..17])
        )
    }

    @TestCase
    public func fixedBufferOverflowIsRejected(): Unit {
        @AssertThrows[IllegalArgumentException](
            encodeToCobs<Telemetry>(
                telemetryValueForCobs(),
                Array<UInt8>(telemetryFrame().size - 1, repeat: 0u8)
            )
        )
    }
}

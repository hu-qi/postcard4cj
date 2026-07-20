package postcard4cj

import std.unittest.*
import std.unittest.testmacro.*

private func telemetryCrcMessage(): Array<UInt8> {
    return [
        0xacu8, 0x02u8, 0x00u8, 0x00u8,
        0x48u8, 0x41u8, 0x01u8, 0x02u8,
        0x6fu8, 0x6bu8, 0x04u8, 0x01u8,
        0x00u8, 0x02u8, 0x80u8, 0x02u8,
        0xaeu8, 0xb6u8, 0xf9u8, 0xb6u8
    ]
}

private func telemetryValueForCrc(): Telemetry {
    return Telemetry(
        300u32,
        12.5f32,
        Some("ok"),
        [-1i16, 0i16, 1i16, 128i16]
    )
}

@Test
public class PostcardCrc32Test {
    @TestCase
    public func officialPostcardCrcVector(): Unit {
        let encoder = PostcardEncoder()
        encoder.writeBytes([0x01u8, 0x00u8, 0x20u8, 0x30u8])

        let payload = encoder.toArray()
        @Assert(payload, [0x04u8, 0x01u8, 0x00u8, 0x20u8, 0x30u8])
        @Assert(crc32Iscsi(payload), 0x371ac88eu32)

        let message = appendCrc32Iscsi(payload)
        @Assert(
            message,
            [
                0x04u8, 0x01u8, 0x00u8, 0x20u8, 0x30u8,
                0x8eu8, 0xc8u8, 0x1au8, 0x37u8
            ]
        )
        @Assert(verifyAndStripCrc32Iscsi(message), payload)
    }

    @TestCase
    public func typedTelemetryCrcMatchesRustPostcard(): Unit {
        let expected = telemetryCrcMessage()
        @Assert(toBytesCrc32Iscsi<Telemetry>(telemetryValueForCrc()), expected)

        let decoded = fromBytesCrc32Iscsi<Telemetry>(expected)
        @Assert(decoded.id, 300u32)
        @Assert(decoded.temperature, 12.5f32)
        @Assert(decoded.note, Some("ok"))
        @Assert(decoded.samples, [-1i16, 0i16, 1i16, 128i16])
    }

    @TestCase
    public func takeVerifiesImmediateChecksumAndReturnsRemainder(): Unit {
        let message = telemetryCrcMessage()
        let input = Array<UInt8>(message.size + 2, repeat: 0u8)
        var index = 0i64
        while (index < message.size) {
            input[index] = message[index]
            index++
        }
        input[index] = 0xaau8
        input[index + 1] = 0xbbu8

        let decoded = takeFromBytesCrc32Iscsi<Telemetry>(input)
        @Assert(decoded[0].id, 300u32)
        @Assert(decoded[1], [0xaau8, 0xbbu8])
    }

    @TestCase
    public func fixedBufferWritesMessageAndPreservesTail(): Unit {
        let expected = telemetryCrcMessage()
        let buffer = Array<UInt8>(expected.size + 2, repeat: 0xeeu8)
        let used = encodeToCrc32Iscsi<Telemetry>(telemetryValueForCrc(), buffer)

        @Assert(used, expected.size)
        @Assert(buffer[..used], expected)
        @Assert(buffer[used..buffer.size], [0xeeu8, 0xeeu8])
    }

    @TestCase
    public func corruptedChecksumIsRejected(): Unit {
        let message = telemetryCrcMessage()
        message[message.size - 1] ^= 0x01u8
        @AssertThrows[IllegalArgumentException](
            fromBytesCrc32Iscsi<Telemetry>(message)
        )
    }

    @TestCase
    public func takeRejectsMissingChecksum(): Unit {
        let payload = toBytes<Telemetry>(telemetryValueForCrc())
        @AssertThrows[IllegalArgumentException](
            takeFromBytesCrc32Iscsi<Telemetry>(payload)
        )
    }

    @TestCase
    public func fixedBufferOverflowIsRejected(): Unit {
        @AssertThrows[IllegalArgumentException](
            encodeToCrc32Iscsi<Telemetry>(
                telemetryValueForCrc(),
                Array<UInt8>(telemetryCrcMessage().size - 1, repeat: 0u8)
            )
        )
    }
}

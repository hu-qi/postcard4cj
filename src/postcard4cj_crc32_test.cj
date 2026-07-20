package postcard4cj

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class PostcardCrc32Test {
    @TestCase
    public func officialPostcardCrcVector(): Unit {
        let encoder = PostcardEncoder()
        encoder.writeBytes([0x01u8,0x00u8,0x20u8,0x30u8])
        let payload = encoder.toArray()
        @Assert(payload,[0x04u8,0x01u8,0x00u8,0x20u8,0x30u8])
        @Assert(crc32Iscsi(payload),0x371ac88eu32)
        let message = appendCrc32Iscsi(payload)
        @Assert(message,[0x04u8,0x01u8,0x00u8,0x20u8,0x30u8,0x8eu8,0xc8u8,0x1au8,0x37u8])
        @Assert(verifyAndStripCrc32Iscsi(message),payload)
    }

    @TestCase
    public func typedTelemetryCrcMatchesRustPostcard(): Unit {
        let telemetry = Telemetry(300u32,12.5f32,Some("ok"),[-1i16,0i16,1i16,128i16])
        let expected: Array<UInt8> = [0xacu8,0x02u8,0x00u8,0x00u8,0x48u8,0x41u8,0x01u8,0x02u8,0x6fu8,0x6bu8,0x04u8,0x01u8,0x00u8,0x02u8,0x80u8,0x02u8,0xaeu8,0xb6u8,0xf9u8,0xb6u8]
        @Assert(toBytesCrc32Iscsi<Telemetry>(telemetry), expected)
        let decoded = fromBytesCrc32Iscsi<Telemetry>(expected)
        @Assert(decoded.id,300u32)
        @Assert(decoded.temperature,12.5f32)
        @Assert(decoded.note,Some("ok"))
        @Assert(decoded.samples,[-1i16,0i16,1i16,128i16])
    }
}

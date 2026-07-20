package postcard4cj

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class PostcardEdgeTest {
    @TestCase
    public func signedByteUsesTwosComplement(): Unit {
        let encoder = PostcardEncoder()
        encoder.writeInt8(-128i8)
        encoder.writeInt8(-1i8)
        encoder.writeInt8(0i8)
        encoder.writeInt8(127i8)
        let bytes = encoder.toArray()
        @Assert(bytes, [0x80u8, 0xffu8, 0x00u8, 0x7fu8])
        let decoder = PostcardDecoder(bytes)
        @Assert(decoder.readInt8(), -128i8)
        @Assert(decoder.readInt8(), -1i8)
        @Assert(decoder.readInt8(), 0i8)
        @Assert(decoder.readInt8(), 127i8)
    }

    @TestCase
    public func stringLengthUsesUtf8ByteCount(): Unit {
        let encoder = PostcardEncoder()
        encoder.writeString("仓颉")
        let bytes = encoder.toArray()
        @Assert(bytes, [6u8, 228u8, 187u8, 147u8, 233u8, 162u8, 137u8])
        let decoder = PostcardDecoder(bytes)
        @Assert(decoder.readString(), "仓颉")
        @Assert(decoder.remaining(), 0)
    }
}

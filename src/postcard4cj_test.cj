package postcard4cj

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class PostcardVarintTest {
    @TestCase
    public func unsignedBoundaries(): Unit {
        @Assert(encodeUInt64(0u64), [0u8])
        @Assert(encodeUInt64(1u64), [1u8])
        @Assert(encodeUInt64(127u64), [0x7fu8])
        @Assert(encodeUInt64(128u64), [0x80u8, 0x01u8])
        @Assert(encodeUInt64(16384u64), [0x80u8, 0x80u8, 0x01u8])
        @Assert(encodeUInt64(0xffff_ffffu64), [0xffu8, 0xffu8, 0xffu8, 0xffu8, 0x0fu8])
    }

    @TestCase
    public func unsignedRoundTrip(): Unit {
        let values: Array<UInt64> = [0u64, 1u64, 127u64, 128u64, 255u64, 16384u64, 0xffff_ffffu64, 0xffff_ffff_ffff_ffffu64]
        for (value in values) {
            let bytes = encodeUInt64(value)
            let decoded = decodeUInt64(bytes)
            @Assert(decoded[0], value)
            @Assert(decoded[1], bytes.size)
        }
    }
}

@Test
public class PostcardZigZagTest {
    @TestCase
    public func knownValues(): Unit {
        @Assert(zigZagEncodeInt64(0i64), 0u64)
        @Assert(zigZagEncodeInt64(-1i64), 1u64)
        @Assert(zigZagEncodeInt64(1i64), 2u64)
        @Assert(zigZagEncodeInt64(-2i64), 3u64)
        @Assert(zigZagDecodeInt64(0u64), 0i64)
        @Assert(zigZagDecodeInt64(1u64), -1i64)
        @Assert(zigZagDecodeInt64(2u64), 1i64)
        @Assert(zigZagDecodeInt64(3u64), -2i64)
    }

    @TestCase
    public func signedRoundTrip(): Unit {
        let values: Array<Int64> = [-9223372036854775807i64 - 1i64, -65536i64, -1i64, 0i64, 1i64, 65536i64, 9223372036854775807i64]
        for (value in values) {
            @Assert(zigZagDecodeInt64(zigZagEncodeInt64(value)), value)
        }
    }
}

@Test
public class PostcardCodecTest {
    @TestCase
    public func rustCompatibleRecordVector(): Unit {
        let encoder = PostcardEncoder()
        encoder.writeUInt32(42u32)
        encoder.writeInt32(-1i32)
        encoder.writeBool(true)
        encoder.writeString("Hi")
        let bytes = encoder.toArray()
        @Assert(bytes, [42u8, 1u8, 1u8, 2u8, 72u8, 105u8])
        let decoder = PostcardDecoder(bytes)
        @Assert(decoder.readUInt32(), 42u32)
        @Assert(decoder.readInt32(), -1i32)
        @Assert(decoder.readBool(), true)
        @Assert(decoder.readString(), "Hi")
        @Assert(decoder.remaining(), 0)
    }

    @TestCase
    public func bytesAreLengthPrefixed(): Unit {
        let encoder = PostcardEncoder()
        encoder.writeBytes([1u8, 0u8, 32u8, 48u8])
        @Assert(encoder.toArray(), [4u8, 1u8, 0u8, 32u8, 48u8])
    }
}

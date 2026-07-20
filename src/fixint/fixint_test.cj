package postcard4cj.fixint

import postcard4cj.core.*
import postcard4cj.flavors.*
import postcard4cj.serde_model.*
import std.math.numeric.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class FixedIntegerCodecTest {
    @TestCase
    public func unsignedLittleAndBigEndianVectors(): Unit {
        let serializer = Serializer(ArraySerializeFlavor())
        serializeUInt16LE(serializer, 0xabcdu16)
        serializeUInt16BE(serializer, 0xabcdu16)
        serializeUInt32LE(serializer, 0x1234_5678u32)
        serializeUInt32BE(serializer, 0x1234_5678u32)
        @Assert(
            serializer.finalize(),
            [
                0xcdu8, 0xabu8,
                0xabu8, 0xcdu8,
                0x78u8, 0x56u8, 0x34u8, 0x12u8,
                0x12u8, 0x34u8, 0x56u8, 0x78u8
            ]
        )
    }

    @TestCase
    public func signedValuesUseTwosComplement(): Unit {
        let serializer = Serializer(ArraySerializeFlavor())
        serializeInt16LE(serializer, -2i16)
        serializeInt16BE(serializer, -2i16)
        serializeInt32LE(serializer, -2i32)
        serializeInt32BE(serializer, -2i32)
        @Assert(
            serializer.finalize(),
            [
                0xfeu8, 0xffu8,
                0xffu8, 0xfeu8,
                0xfeu8, 0xffu8, 0xffu8, 0xffu8,
                0xffu8, 0xffu8, 0xffu8, 0xfeu8
            ]
        )
    }

    @TestCase
    public func fixedValuesRoundTrip(): Unit {
        let bytes: Array<UInt8> = [
            0xcdu8, 0xabu8,
            0x12u8, 0x34u8, 0x56u8, 0x78u8,
            0xfeu8, 0xffu8,
            0xffu8, 0xffu8, 0xffu8, 0xfeu8
        ]
        let deserializer = Deserializer(SliceDeserializeFlavor(bytes))
        @Assert(deserializeUInt16LE(deserializer), 0xabcdu16)
        @Assert(deserializeUInt32BE(deserializer), 0x1234_5678u32)
        @Assert(deserializeInt16LE(deserializer), -2i16)
        @Assert(deserializeInt32BE(deserializer), -2i32)
        @Assert(deserializer.finalize(), [])
    }

    @TestCase
    public func uint64MaximumRoundTripsWithoutSignedNarrowing(): Unit {
        let serializer = Serializer(ArraySerializeFlavor())
        serializeUInt64LE(serializer, 0xffff_ffff_ffff_ffffu64)
        let bytes = serializer.finalize()
        @Assert(
            bytes,
            [
                0xffu8, 0xffu8, 0xffu8, 0xffu8,
                0xffu8, 0xffu8, 0xffu8, 0xffu8
            ]
        )
        let deserializer = Deserializer(SliceDeserializeFlavor(bytes))
        @Assert(deserializeUInt64LE(deserializer), 0xffff_ffff_ffff_ffffu64)
    }

    @TestCase
    public func int128MinimumAndUInt128MaximumRoundTrip(): Unit {
        let signedMinimum = BigInt.parse("-170141183460469231731687303715884105728")
        let unsignedMaximum = BigInt.parse("340282366920938463463374607431768211455")
        let serializer = Serializer(ArraySerializeFlavor())
        serializeInt128BE(serializer, signedMinimum)
        serializeUInt128LE(serializer, unsignedMaximum)
        let bytes = serializer.finalize()

        @Assert(bytes[0], 0x80u8)
        var index = 1i64
        while (index < 16) {
            @Assert(bytes[index], 0x00u8)
            index++
        }
        while (index < 32) {
            @Assert(bytes[index], 0xffu8)
            index++
        }

        let deserializer = Deserializer(SliceDeserializeFlavor(bytes))
        @Assert(deserializeInt128BE(deserializer), signedMinimum)
        @Assert(deserializeUInt128LE(deserializer), unsignedMaximum)
    }

    @TestCase
    public func outOfRangeValueIsRejected(): Unit {
        let serializer = Serializer(ArraySerializeFlavor())
        @AssertThrows[PostcardException](
            serializeUInt128LE(serializer, BigInt(1i64) << 128i64)
        )
    }
}

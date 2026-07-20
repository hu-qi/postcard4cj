package postcard4cj.core

import std.math.numeric.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CorePrimitiveCodecTest {
    @TestCase
    public func primitiveVectorMatchesRustPostcard(): Unit {
        let encoder = CoreEncoder()
        encoder.pushBool(true)
        encoder.pushInt8(-1i8)
        encoder.pushInt16(-1i16)
        encoder.pushInt32(-1i32)
        encoder.pushInt64(-1i64)
        encoder.pushUInt8(42u8)
        encoder.pushUInt16(128u16)
        encoder.pushUInt32(300u32)
        encoder.pushUInt64(16384u64)
        encoder.pushFloat32(12.5f32)
        encoder.pushFloat64(12.5f64)
        encoder.pushRune(r'爱')
        encoder.pushString("Hi")
        encoder.pushOptionSome()
        encoder.pushDiscriminant(2u32)

        let bytes = encoder.toArray()
        let decoder = CoreDecoder(bytes)
        @Assert(decoder.takeBool(), true)
        @Assert(decoder.takeInt8(), -1i8)
        @Assert(decoder.takeInt16(), -1i16)
        @Assert(decoder.takeInt32(), -1i32)
        @Assert(decoder.takeInt64(), -1i64)
        @Assert(decoder.takeUInt8(), 42u8)
        @Assert(decoder.takeUInt16(), 128u16)
        @Assert(decoder.takeUInt32(), 300u32)
        @Assert(decoder.takeUInt64(), 16384u64)
        @Assert(decoder.takeFloat32(), 12.5f32)
        @Assert(decoder.takeFloat64(), 12.5f64)
        @Assert(decoder.takeRune(), r'爱')
        @Assert(decoder.takeString(), "Hi")
        match (decoder.takeOptionDiscriminant()) {
            case PostcardOptionDiscriminant.SomeValue => ()
            case _ => throw IllegalStateException("Expected Some discriminant")
        }
        @Assert(decoder.takeDiscriminant(), 2u32)
        @Assert(decoder.remaining(), 0)
    }

    @TestCase
    public func int128BoundariesRoundTrip(): Unit {
        let unsignedMaximum = BigInt.parse("340282366920938463463374607431768211455")
        let signedMinimum = BigInt.parse("-170141183460469231731687303715884105728")
        let encoder = CoreEncoder()
        encoder.pushUInt128(unsignedMaximum)
        encoder.pushInt128(signedMinimum)

        let decoder = CoreDecoder(encoder.toArray())
        @Assert(decoder.takeUInt128(), unsignedMaximum)
        @Assert(decoder.takeInt128(), signedMinimum)
        @Assert(decoder.remaining(), 0)
    }

    @TestCase
    public func fixedBufferReportsPostcardException(): Unit {
        let encoder = CoreEncoder(Array<UInt8>(1, repeat: 0u8))
        encoder.pushUInt8(1u8)
        @AssertThrows[PostcardException](encoder.pushUInt8(2u8))
    }
}

@Test
public class CoreNegativeVectorTest {
    @TestCase
    public func rejectsInvalidBool(): Unit {
        let decoder = CoreDecoder([2u8])
        @AssertThrows[PostcardException](decoder.takeBool())
    }

    @TestCase
    public func rejectsInvalidOption(): Unit {
        let decoder = CoreDecoder([2u8])
        @AssertThrows[PostcardException](decoder.takeOptionDiscriminant())
    }

    @TestCase
    public func rejectsOverflowingUInt32Varint(): Unit {
        let decoder = CoreDecoder([0xffu8, 0xffu8, 0xffu8, 0xffu8, 0x1fu8])
        @AssertThrows[PostcardException](decoder.takeUInt32())
    }

    @TestCase
    public func rejectsTruncatedInput(): Unit {
        let decoder = CoreDecoder([4u8, 1u8, 2u8])
        @AssertThrows[PostcardException](decoder.takeBytes())
    }
}

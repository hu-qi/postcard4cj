package postcard4cj

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class PostcardRuneTest {
    @TestCase
    public func asciiAndMultibyteVectors(): Unit {
        let encoder = PostcardEncoder()
        encoder.writeRune(r'A')
        encoder.writeRune(r'爱')
        @Assert(encoder.toArray(),[0x01u8,0x41u8,0x03u8,0xe7u8,0x88u8,0xb1u8])
        let decoder = PostcardDecoder(encoder.toArray())
        @Assert(decoder.readRune(),r'A')
        @Assert(decoder.readRune(),r'爱')
        @Assert(decoder.remaining(),0)
    }
}

@Test
public class PostcardCompoundCodecTest {
    @TestCase
    public func unitTupleMapAndEnumVector(): Unit {
        let encoder = PostcardEncoder()
        encoder.writeRune(r'爱')
        encoder.writeUnit()
        encoder.writeTuple2<UInt8,Int16>((7u8,-1i16),{value: UInt8 => encoder.writeUInt8(value)},{value: Int16 => encoder.writeInt16(value)})
        encoder.writeMapEntries<UInt8,String>([(1u8,"a"),(2u8,"b")],{key: UInt8 => encoder.writeUInt8(key)},{value: String => encoder.writeString(value)})
        encoder.writeEnumIndex(1u32)
        encoder.writeUInt16(128u16)
        let expected: Array<UInt8> = [0x03u8,0xe7u8,0x88u8,0xb1u8,0x07u8,0x01u8,0x02u8,0x01u8,0x01u8,0x61u8,0x02u8,0x01u8,0x62u8,0x01u8,0x80u8,0x01u8]
        @Assert(encoder.toArray(),expected)
        let decoder = PostcardDecoder(expected)
        @Assert(decoder.readRune(),r'爱')
        decoder.readUnit()
        let pair = decoder.readTuple2<UInt8,Int16>({=> decoder.readUInt8()},{=> decoder.readInt16()})
        @Assert(pair[0],7u8)
        @Assert(pair[1],-1i16)
        let entries = decoder.readMapEntries<UInt8,String>({=> decoder.readUInt8()},{=> decoder.readString()})
        @Assert(entries.size,2)
        @Assert(entries[0][0],1u8)
        @Assert(entries[0][1],"a")
        @Assert(entries[1][0],2u8)
        @Assert(entries[1][1],"b")
        @Assert(decoder.readEnumIndex(),1u32)
        @Assert(decoder.readUInt16(),128u16)
        @Assert(decoder.remaining(),0)
    }

    @TestCase
    public func untrustedMapLengthDoesNotPreallocateWireCount(): Unit {
        let encoder = PostcardEncoder()
        encoder.writeSequenceLength(1_000_000_000i64)
        let decoder = PostcardDecoder(encoder.toArray())
        @AssertThrows[Exception](
            decoder.readMapEntries<UInt8,UInt8>(
                {=> decoder.readUInt8()},
                {=> decoder.readUInt8()}
            )
        )
    }
}

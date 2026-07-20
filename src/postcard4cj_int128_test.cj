package postcard4cj

import std.math.numeric.*
import std.unittest.*
import std.unittest.testmacro.*

public struct WideValues <: PostcardEncode & PostcardDecode<WideValues> {
    public let unsignedMaximum: BigInt
    public let signedMinimum: BigInt
    public let signedSample: BigInt

    public init(unsignedMaximum: BigInt, signedMinimum: BigInt, signedSample: BigInt) {
        this.unsignedMaximum = unsignedMaximum
        this.signedMinimum = signedMinimum
        this.signedSample = signedSample
    }

    public func encode(encoder: PostcardEncoder): Unit {
        encoder.writeUInt128(unsignedMaximum)
        encoder.writeInt128(signedMinimum)
        encoder.writeInt128(signedSample)
    }

    public static func decode(decoder: PostcardDecoder): WideValues {
        return WideValues(decoder.readUInt128(), decoder.readInt128(), decoder.readInt128())
    }
}

@Test
public class PostcardInt128Test {
    @TestCase
    public func unsignedAndSignedBoundaries(): Unit {
        let unsignedMaximum = BigInt.parse("340282366920938463463374607431768211455")
        let signedMinimum = BigInt.parse("-170141183460469231731687303715884105728")
        let maxVarint: Array<UInt8> = [0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0x03u8]
        @Assert(encodeUInt128(unsignedMaximum), maxVarint)
        @Assert(encodeUInt128(zigZagEncodeInt128(signedMinimum)), maxVarint)
        @Assert(zigZagDecodeInt128(zigZagEncodeInt128(signedMinimum)), signedMinimum)
    }

    @TestCase
    public func rustSignedSampleVector(): Unit {
        let sample = BigInt.parse("-19490127978232325886905073712831")
        let expected: Array<UInt8> = [0xfdu8,0xfau8,0xf5u8,0xebu8,0xf7u8,0xffu8,0xffu8,0xffu8,0xffu8,0xc3u8,0xffu8,0xffu8,0xffu8,0xffu8,0x7au8]
        let encoder = PostcardEncoder()
        encoder.writeInt128(sample)
        @Assert(encoder.toArray(), expected)
        let decoder = PostcardDecoder(expected)
        @Assert(decoder.readInt128(), sample)
        @Assert(decoder.remaining(), 0)
    }

    @TestCase
    public func typedWideVectorMatchesRustPostcard(): Unit {
        let value = WideValues(BigInt.parse("340282366920938463463374607431768211455"), BigInt.parse("-170141183460469231731687303715884105728"), BigInt.parse("-19490127978232325886905073712831"))
        let expected: Array<UInt8> = [0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0x03u8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0xffu8,0x03u8,0xfdu8,0xfau8,0xf5u8,0xebu8,0xf7u8,0xffu8,0xffu8,0xffu8,0xffu8,0xc3u8,0xffu8,0xffu8,0xffu8,0xffu8,0x7au8]
        @Assert(toBytes<WideValues>(value), expected)
        let decoded = fromBytes<WideValues>(expected)
        @Assert(decoded.unsignedMaximum, value.unsignedMaximum)
        @Assert(decoded.signedMinimum, value.signedMinimum)
        @Assert(decoded.signedSample, value.signedSample)
    }
}

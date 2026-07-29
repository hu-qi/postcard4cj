package postcard4cj.flavors

import postcard4cj.core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class SerializeFlavorTest {
    @TestCase
    public func arrayAndSliceStorage(): Unit {
        let growable = ArraySerializeFlavor()
        growable.tryPush(1u8)
        growable.tryExtend([2u8, 3u8])
        @Assert(growable.position(), 3)
        @Assert(growable.finalize(), [1u8, 2u8, 3u8])

        let buffer = Array<UInt8>(5, repeat: 0xeeu8)
        let fixed = SliceSerializeFlavor(buffer)
        fixed.tryExtend([1u8, 2u8, 3u8])
        @Assert(fixed.finalize(), [1u8, 2u8, 3u8])
        @Assert(buffer[3..5], [0xeeu8, 0xeeu8])
    }

    @TestCase
    public func sliceOverflowUsesPostcardError(): Unit {
        let fixed = SliceSerializeFlavor(Array<UInt8>(1, repeat: 0u8))
        fixed.tryPush(1u8)
        @AssertThrows[PostcardException](fixed.tryPush(2u8))
    }

    @TestCase
    public func sizeFlavorCountsWithoutStoring(): Unit {
        let size = SizeSerializeFlavor()
        size.tryPush(1u8)
        size.tryExtend([2u8, 3u8, 4u8])
        @Assert(size.position(), 4)
        @Assert(size.finalize(), [])
    }

    @TestCase
    public func cobsFlavorMatchesPostcardVector(): Unit {
        let flavor = CobsSerializeFlavor(ArraySerializeFlavor())
        flavor.tryExtend([0x04u8, 0x01u8, 0x00u8, 0x20u8, 0x30u8])
        let expected: Array<UInt8> = [0x03u8, 0x04u8, 0x01u8, 0x03u8, 0x20u8, 0x30u8, 0x00u8]
        @Assert(flavor.snapshot(), expected)
        @Assert(flavor.finalize(), expected)
    }

    @TestCase
    public func cobsFlavorHandlesFullLengthBlockIncrementally(): Unit {
        let payload = Array<UInt8>(254, repeat: 0x7fu8)
        let flavor = CobsSerializeFlavor(ArraySerializeFlavor())
        flavor.tryExtend(payload)
        @Assert(flavor.position(), 254)
        let encoded = flavor.finalize()
        @Assert(encoded.size, 257)
        @Assert(encoded[0], 0xffu8)
        @Assert(encoded[1..255], payload)
        @Assert(encoded[255], 0x01u8)
        @Assert(encoded[256], 0x00u8)
    }

    @TestCase
    public func crcFlavorMatchesPostcardVector(): Unit {
        let flavor = Crc32SerializeFlavor(ArraySerializeFlavor())
        flavor.tryExtend([0x04u8, 0x01u8, 0x00u8, 0x20u8, 0x30u8])
        let expected: Array<UInt8> = [
            0x04u8, 0x01u8, 0x00u8, 0x20u8, 0x30u8,
            0x8eu8, 0xc8u8, 0x1au8, 0x37u8
        ]
        @Assert(flavor.snapshot(), expected)
        @Assert(flavor.finalize(), expected)
    }

    @TestCase
    public func crcFlavorUpdatesAcrossSeparateWrites(): Unit {
        let flavor = Crc32SerializeFlavor(ArraySerializeFlavor())
        flavor.tryPush(0x04u8)
        flavor.tryExtend([0x01u8, 0x00u8])
        flavor.tryExtend([0x20u8, 0x30u8])
        @Assert(flavor.position(), 5)
        @Assert(
            flavor.finalize(),
            [
                0x04u8, 0x01u8, 0x00u8, 0x20u8, 0x30u8,
                0x8eu8, 0xc8u8, 0x1au8, 0x37u8
            ]
        )
    }

    @TestCase
    public func crcFlavorAcceptsCallerSelectedDigest(): Unit {
        let flavor = Crc32SerializeFlavor(
            ArraySerializeFlavor(),
            crc32IsoHdlcDigest()
        )
        flavor.tryExtend([
            0x31u8, 0x32u8, 0x33u8, 0x34u8, 0x35u8,
            0x36u8, 0x37u8, 0x38u8, 0x39u8
        ])
        let message = flavor.finalize()
        @Assert(
            message[message.size - 4..message.size],
            [0x26u8, 0x39u8, 0xf4u8, 0xcbu8]
        )
        let source = Crc32DeserializeFlavor(message, crc32IsoHdlcDigest())
        @Assert(source.tryTake(9), message[..9])
    }

    @TestCase
    public func flavorsComposeInDeclaredOrder(): Unit {
        let flavor = CobsSerializeFlavor(
            Crc32SerializeFlavor(ArraySerializeFlavor())
        )
        flavor.tryExtend([0x04u8, 0x01u8, 0x00u8, 0x20u8, 0x30u8])
        let message = flavor.finalize()

        let crcSource = Crc32DeserializeFlavor(message)
        let cobsFrame = crcSource.tryTake(match (crcSource.sizeHint()) {
            case Some(value) => value
            case None => throw IllegalStateException("Expected size hint")
        })
        let cobsSource = CobsDeserializeFlavor(cobsFrame)
        @Assert(cobsSource.tryTake(5), [0x04u8, 0x01u8, 0x00u8, 0x20u8, 0x30u8])
        @Assert(cobsSource.finalize(), [])
    }
}

@Test
public class DeserializeFlavorTest {
    @TestCase
    public func sliceTracksRemainder(): Unit {
        let source = SliceDeserializeFlavor([1u8, 2u8, 3u8, 4u8])
        @Assert(source.pop(), 1u8)
        @Assert(source.tryTake(2), [2u8, 3u8])
        @Assert(source.position(), 3)
        @Assert(source.finalize(), [4u8])
    }

    @TestCase
    public func cobsSourceDecodesFrame(): Unit {
        let source = CobsDeserializeFlavor([
            0x03u8, 0x04u8, 0x01u8, 0x03u8, 0x20u8, 0x30u8, 0x00u8
        ])
        @Assert(source.tryTake(5), [0x04u8, 0x01u8, 0x00u8, 0x20u8, 0x30u8])
        @Assert(source.finalize(), [])
    }

    @TestCase
    public func crcSourceRejectsCorruption(): Unit {
        @AssertThrows[PostcardException](
            Crc32DeserializeFlavor([
                0x04u8, 0x01u8, 0x00u8, 0x20u8, 0x30u8,
                0x8eu8, 0xc8u8, 0x1au8, 0x36u8
            ])
        )
    }

    @TestCase
    public func sourceRejectsTruncatedTake(): Unit {
        let source = SliceDeserializeFlavor([1u8])
        @AssertThrows[PostcardException](source.tryTake(2))
    }
}

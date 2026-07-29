package postcard4cj.serde_model

import postcard4cj.core.*
import postcard4cj.flavors.*
import std.unittest.*
import std.unittest.testmacro.*

public struct ModelRecord <: PostcardSerialize & PostcardDeserialize<ModelRecord> {
    public let id: UInt32
    public let delta: Int32
    public let active: Bool
    public let name: String
    public let samples: Array<UInt16>

    public init(
        id: UInt32,
        delta: Int32,
        active: Bool,
        name: String,
        samples: Array<UInt16>
    ) {
        this.id = id
        this.delta = delta
        this.active = active
        this.name = name
        this.samples = samples
    }

    public func serialize(serializer: Serializer): Unit {
        serializer.beginStruct("ModelRecord", 5)
        serializer.serializeUInt32(id)
        serializer.serializeInt32(delta)
        serializer.serializeBool(active)
        serializer.serializeString(name)
        serializer.serializeSequence<UInt16>(
            samples,
            {value: UInt16 => serializer.serializeUInt16(value)}
        )
        serializer.endContainer()
    }

    public static func deserialize(deserializer: Deserializer): ModelRecord {
        deserializer.beginStruct("ModelRecord", 5)
        let id = deserializer.deserializeUInt32()
        let delta = deserializer.deserializeInt32()
        let active = deserializer.deserializeBool()
        let name = deserializer.deserializeString()
        let samples = deserializer.deserializeSequence<UInt16>(
            {=> deserializer.deserializeUInt16()}
        )
        deserializer.endContainer()
        return ModelRecord(id, delta, active, name, samples)
    }
}

@Test
public class SerializerModelTest {
    private let value = ModelRecord(42u32, -1i32, true, "Hi", [1u16, 128u16])
    private let expected: Array<UInt8> = [
        0x2au8, 0x01u8, 0x01u8, 0x02u8, 0x48u8, 0x69u8,
        0x02u8, 0x01u8, 0x80u8, 0x01u8
    ]

    @TestCase
    public func typedRoundTripMatchesRustWireFormat(): Unit {
        @Assert(toByteArray<ModelRecord>(value), expected)

        let decoded = fromByteArray<ModelRecord>(expected)
        @Assert(decoded.id, 42u32)
        @Assert(decoded.delta, -1i32)
        @Assert(decoded.active, true)
        @Assert(decoded.name, "Hi")
        @Assert(decoded.samples, [1u16, 128u16])
    }

    @TestCase
    public func fixedSliceAndSizeFlavorAgree(): Unit {
        let buffer = Array<UInt8>(16, repeat: 0xeeu8)
        let used = toSlice<ModelRecord>(value, buffer)
        @Assert(used, expected.size)
        @Assert(buffer[..used], expected)
        @Assert(serializedSize<ModelRecord>(value), expected.size)
    }

    @TestCase
    public func takeReturnsUnusedRemainder(): Unit {
        let input: Array<UInt8> = [
            0x2au8, 0x01u8, 0x01u8, 0x02u8, 0x48u8, 0x69u8,
            0x02u8, 0x01u8, 0x80u8, 0x01u8, 0xaau8, 0xbbu8
        ]
        let decoded = takeFromByteArray<ModelRecord>(input)
        @Assert(decoded[0].name, "Hi")
        @Assert(decoded[1], [0xaau8, 0xbbu8])
    }

    @TestCase
    public func exactDecodeRejectsTrailingBytes(): Unit {
        let input: Array<UInt8> = [
            0x2au8, 0x01u8, 0x01u8, 0x02u8, 0x48u8, 0x69u8,
            0x02u8, 0x01u8, 0x80u8, 0x01u8, 0xffu8
        ]
        @AssertThrows[PostcardException](fromByteArray<ModelRecord>(input))
    }

    @TestCase
    public func sequenceAndMapRequireKnownLength(): Unit {
        let serializer = Serializer(ArraySerializeFlavor())
        @AssertThrows[PostcardException](serializer.beginSequence(None))
        @AssertThrows[PostcardException](serializer.beginMap(None))
    }

    @TestCase
    public func mapEntriesUseLengthThenKeyValuePairs(): Unit {
        let serializer = Serializer(ArraySerializeFlavor())
        serializer.serializeMapEntries<UInt8, String>(
            [(1u8, "a"), (2u8, "b")],
            {key: UInt8 => serializer.serializeUInt8(key)},
            {item: String => serializer.serializeString(item)}
        )
        @Assert(
            serializer.finalize(),
            [0x02u8, 0x01u8, 0x01u8, 0x61u8, 0x02u8, 0x01u8, 0x62u8]
        )
    }

    @TestCase
    public func aggregateHeadersAndVariantsMatchSerdeModel(): Unit {
        let serializer = Serializer(ArraySerializeFlavor())
        serializer.serializeUnit()
        serializer.beginUnitStruct("UnitStruct")
        serializer.beginNewtypeStruct("Newtype")
        serializer.beginTuple(2)
        serializer.serializeUInt8(7u8)
        serializer.serializeInt16(-1i16)
        serializer.beginTupleVariant(2u32, 2)
        serializer.serializeString("x")
        serializer.serializeBool(true)
        @Assert(
            serializer.finalize(),
            [0x07u8, 0x01u8, 0x02u8, 0x01u8, 0x78u8, 0x01u8]
        )
    }

    @TestCase
    public func cobsFlavorIntegratesWithTypedSerializer(): Unit {
        let frame = serializeWithFlavor<ModelRecord>(
            value,
            CobsSerializeFlavor(ArraySerializeFlavor())
        )
        let deserializer = Deserializer(CobsDeserializeFlavor(frame))
        let decoded = ModelRecord.deserialize(deserializer)
        @Assert(decoded.id, 42u32)
        @Assert(decoded.samples, [1u16, 128u16])
        @Assert(deserializer.finalize(), [])
    }
}

@Test
public class DeserializerModelTest {
    @TestCase
    public func optionAndVariantDiscriminants(): Unit {
        let deserializer = Deserializer(SliceDeserializeFlavor([
            0x00u8, 0x01u8, 0x80u8, 0x01u8, 0x02u8
        ]))
        @Assert(
            deserializer.deserializeOption<UInt16>({=> deserializer.deserializeUInt16()}),
            None
        )
        @Assert(
            deserializer.deserializeOption<UInt16>({=> deserializer.deserializeUInt16()}),
            Some(128u16)
        )
        @Assert(deserializer.deserializeVariantIndex(), 2u32)
    }

    @TestCase
    public func deserializeAnyIsRejected(): Unit {
        let deserializer = Deserializer(SliceDeserializeFlavor([]))
        @AssertThrows[PostcardException](deserializer.deserializeAny())
    }

    @TestCase
    public func invalidUtf8UsesPostcardError(): Unit {
        let deserializer = Deserializer(SliceDeserializeFlavor([1u8, 0xffu8]))
        @AssertThrows[PostcardException](deserializer.deserializeString())
    }

    @TestCase
    public func untrustedCollectionLengthsDoNotPreallocateWireCount(): Unit {
        let maliciousLength: Array<UInt8> = [
            0xffu8, 0xffu8, 0xffu8, 0xffu8, 0x0fu8
        ]
        let sequence = Deserializer(SliceDeserializeFlavor(maliciousLength))
        @AssertThrows[PostcardException](
            sequence.deserializeSequence<UInt8>({=> sequence.deserializeUInt8()})
        )

        let map = Deserializer(SliceDeserializeFlavor(maliciousLength))
        @AssertThrows[PostcardException](
            map.deserializeMapEntries<UInt8, UInt8>(
                {=> map.deserializeUInt8()},
                {=> map.deserializeUInt8()}
            )
        )
    }
}

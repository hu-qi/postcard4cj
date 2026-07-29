package postcard4cj.schema

import postcard4cj.core.*
import postcard4cj.serde_model.*
import std.unittest.*
import std.unittest.testmacro.*

private func recordSchema(): NamedType {
    return structSchema("Record", [
        NamedValue("id", uint32Schema()),
        NamedValue("active", boolSchema()),
        NamedValue("note", optionSchema(stringSchema()))
    ])
}

private func commandSchema(): NamedType {
    return enumSchema("Command", [
        NamedVariant("Ping", DataModelVariant.UnitVariant),
        NamedVariant("SetSpeed", DataModelVariant.NewtypeVariant(uint16Schema())),
        NamedVariant("Rename", DataModelVariant.StructVariant([
            NamedValue("name", stringSchema()),
            NamedValue("enabled", boolSchema())
        ]))
    ])
}

public struct KeyRecord <: PostcardSchema<KeyRecord> {
    public static func schema(): NamedType {
        return structSchema("KeyRecord", [
            NamedValue("id", uint32Schema()),
            NamedValue("active", boolSchema())
        ])
    }
}

@Test
public class SchemaModelTest {
    @TestCase
    public func primitiveSchemaUsesUpstreamWireIndex(): Unit {
        @Assert(
            toByteArray<NamedType>(uint32Schema()),
            [0x03u8, 0x75u8, 0x33u8, 0x32u8, 0x08u8]
        )
    }

    @TestCase
    public func complexSchemaRoundTrips(): Unit {
        let original = recordSchema()
        let bytes = toByteArray<NamedType>(original)
        let decoded = fromByteArray<NamedType>(bytes)

        @Assert(decoded.name, "Record")
        match (decoded.ty) {
            case DataModelType.Struct(fields) =>
                @Assert(fields.size, 3)
                @Assert(fields[0].name, "id")
                @Assert(fields[0].ty.name, "u32")
                @Assert(fields[1].name, "active")
                @Assert(fields[2].name, "note")
                match (fields[2].ty.ty) {
                    case DataModelType.Option(inner) => @Assert(inner.name, "String")
                    case _ => throw IllegalStateException("Expected Option schema")
                }
            case _ => throw IllegalStateException("Expected Struct schema")
        }
    }

    @TestCase
    public func ownedConversionDeepCopiesSchema(): Unit {
        let copied = toOwnedSchema(commandSchema())
        @Assert(copied.name, "Command")
        match (copied.ty) {
            case DataModelType.Enum(variants) =>
                @Assert(variants.size, 3)
                @Assert(variants[2].name, "Rename")
                match (variants[2].ty) {
                    case DataModelVariant.StructVariant(fields) =>
                        @Assert(fields[0].name, "name")
                        @Assert(fields[1].ty.name, "bool")
                    case _ => throw IllegalStateException("Expected struct variant")
                }
            case _ => throw IllegalStateException("Expected Enum schema")
        }
    }

    @TestCase
    public func invalidSchemaVariantUsesPostcardError(): Unit {
        @AssertThrows[PostcardException](
            fromByteArray<DataModelType>([0x1du8])
        )
    }
}

@Test
public class SchemaFormattingTest {
    @TestCase
    public func structAndEnumRenderAsPseudocode(): Unit {
        @Assert(
            formatSchema(recordSchema()),
            "struct Record { id: u32, active: bool, note: Option<String> }"
        )
        @Assert(
            formatSchema(commandSchema()),
            "enum Command { Ping, SetSpeed(u16), Rename { name: String, enabled: bool } }"
        )
    }

    @TestCase
    public func homogeneousTupleRendersAsFixedArray(): Unit {
        @Assert(
            formatSchema(tupleSchema([uint8Schema(), uint8Schema(), uint8Schema()])),
            "[u8; 3]"
        )
        @Assert(
            formatSchema(tupleSchema([uint8Schema(), uint16Schema()])),
            "(u8, u16)"
        )
    }

    @TestCase
    public func enumMapUsesEnumBackingFixedArraySchema(): Unit {
        let schema = enumMapSchema(uint16Schema(), 3)
        @Assert(formatSchema(schema), "[u16; 3]")
        match (schema.ty) {
            case DataModelType.Tuple(elements) =>
                @Assert(elements.size, 3)
                @Assert(elements[0].name, "u16")
            case _ => throw IllegalStateException("Expected fixed-array tuple schema")
        }
        @AssertThrows[IllegalArgumentException](
            enumMapSchema(uint16Schema(), -1)
        )
    }

    @TestCase
    public func recursiveDiscoveryDeduplicatesTypes(): Unit {
        let used = allUsedTypes(recordSchema())
        @Assert(used.size, 5)
        @Assert(used[0].name, "Record")
    }
}

@Test
public class SchemaKeyTest {
    @TestCase
    public func primitiveKeyMatchesUpstreamFnvVector(): Unit {
        @Assert(
            keyForSchemaPath("/example", uint32Schema()).toBytes(),
            [0xc9u8, 0xddu8, 0x9du8, 0xb8u8, 0x95u8, 0xbcu8, 0xe1u8, 0x48u8]
        )
    }

    @TestCase
    public func structKeyMatchesUpstreamFnvVector(): Unit {
        @Assert(
            keyForPath<KeyRecord>("/record").toBytes(),
            [0xf3u8, 0xe3u8, 0x44u8, 0x8du8, 0x90u8, 0x20u8, 0x9eu8, 0x66u8]
        )
    }

    @TestCase
    public func typeDisplayNameIsExcludedButFieldNameIsIncluded(): Unit {
        let first = structSchema("FirstName", [
            NamedValue("id", uint32Schema())
        ])
        let renamedType = structSchema("SecondName", [
            NamedValue("id", uint32Schema())
        ])
        let renamedField = structSchema("FirstName", [
            NamedValue("identifier", uint32Schema())
        ])

        @Assert(
            keyForSchemaPath("/same", first).constCompare(
                keyForSchemaPath("/same", renamedType)
            ),
            true
        )
        @Assert(
            keyForSchemaPath("/same", first).constCompare(
                keyForSchemaPath("/same", renamedField)
            ),
            false
        )
    }

    @TestCase
    public func keyUsesFixedEightByteWireRepresentation(): Unit {
        let key = keyForSchemaPath("/example", uint32Schema())
        @Assert(toByteArray<Key>(key), key.toBytes())
        @Assert(fromByteArray<Key>(key.toBytes()).constCompare(key), true)
    }
}

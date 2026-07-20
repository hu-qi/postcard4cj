package postcard4cj.postcard_macro_test

import postcard4cj.max_size.*
import postcard4cj.postcard_macro.*
import postcard4cj.schema.*
import postcard4cj.serde_model.*
import std.unittest.*
import std.unittest.testmacro.*

@PostcardSchema
public struct DerivedSchemaRecord {
    public let id: UInt32
    public let note: Option<String>
    public let values: Array<UInt16>

    public init(id: UInt32, note: Option<String>, values: Array<UInt16>) {
        this.id = id
        this.note = note
        this.values = values
    }
}

@PostcardSchema
public enum DerivedSchemaCommand {
    | Ping
    | SetSpeed(UInt16)
    | Rename(String, Bool)
}

@PostcardSchema
public struct DerivedInnerSchema {
    public let code: UInt16

    public init(code: UInt16) {
        this.code = code
    }
}

@PostcardSchema
public struct DerivedOuterSchema {
    public let inner: DerivedInnerSchema
    public let enabled: Bool

    public init(inner: DerivedInnerSchema, enabled: Bool) {
        this.inner = inner
        this.enabled = enabled
    }
}

@PostcardMaxSize
public struct DerivedBoundedRecord {
    public let id: UInt32
    public let active: Bool
    public let sample: Option<UInt16>
    public let marker: Rune

    public init(id: UInt32, active: Bool, sample: Option<UInt16>, marker: Rune) {
        this.id = id
        this.active = active
        this.sample = sample
        this.marker = marker
    }
}

@PostcardMaxSize
public struct DerivedBoundedInner {
    public let code: UInt16

    public init(code: UInt16) {
        this.code = code
    }
}

@PostcardMaxSize
public struct DerivedBoundedOuter {
    public let inner: DerivedBoundedInner
    public let enabled: Bool

    public init(inner: DerivedBoundedInner, enabled: Bool) {
        this.inner = inner
        this.enabled = enabled
    }
}

@PostcardMaxSize
public enum DerivedBoundedCommand {
    | Ping
    | SetSpeed(UInt16)
    | Rename(UInt32, Bool)
}

@Test
public class PostcardSchemaDeriveTest {
    @TestCase
    public func namedStructUsesDeclarationOrder(): Unit {
        @Assert(
            formatSchema(DerivedSchemaRecord.schema()),
            "struct DerivedSchemaRecord { id: u32, note: Option<String>, values: [u16] }"
        )
    }

    @TestCase
    public func enumUsesUnitNewtypeAndTupleVariants(): Unit {
        @Assert(
            formatSchema(DerivedSchemaCommand.schema()),
            "enum DerivedSchemaCommand { Ping, SetSpeed(u16), Rename(String, bool) }"
        )
    }

    @TestCase
    public func nestedSchemaCallsNestedImplementation(): Unit {
        @Assert(
            formatSchema(DerivedOuterSchema.schema()),
            "struct DerivedOuterSchema { inner: DerivedInnerSchema, enabled: bool }"
        )
        let used = allUsedTypes(DerivedOuterSchema.schema())
        @Assert(used.size, 4)
        @Assert(used[1].name, "DerivedInnerSchema")
    }

    @TestCase
    public func generatedSchemaHasPostcardWireRepresentation(): Unit {
        let schema = DerivedSchemaCommand.schema()
        let bytes = toByteArray<NamedType>(schema)
        @Assert(formatSchema(fromByteArray<NamedType>(bytes)), formatSchema(schema))
    }

    @TestCase
    public func generatedSchemaProducesStableKey(): Unit {
        let first = keyForPath<DerivedSchemaRecord>("/derived")
        let second = keyForSchemaPath("/derived", DerivedSchemaRecord.schema())
        @Assert(first.constCompare(second), true)
    }
}

@Test
public class PostcardMaxSizeDeriveTest {
    @TestCase
    public func structSumsFieldMaximums(): Unit {
        // u32=5, bool=1, Option<u16>=1+3, Rune=5
        @Assert(DerivedBoundedRecord.postcardMaxSize(), 15)
    }

    @TestCase
    public func nestedTypeUsesNestedMaximum(): Unit {
        @Assert(DerivedBoundedInner.postcardMaxSize(), 3)
        @Assert(DerivedBoundedOuter.postcardMaxSize(), 4)
    }

    @TestCase
    public func enumAddsDiscriminantToLargestPayload(): Unit {
        // Three variants => one-byte discriminant; largest payload u32+bool = 6.
        @Assert(DerivedBoundedCommand.postcardMaxSize(), 7)
    }
}

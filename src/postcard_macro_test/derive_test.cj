package postcard4cj.postcard_macro_test

import postcard4cj.max_size.*
import postcard4cj.postcard_macro.*
import postcard4cj.schema.*
import postcard4cj.serde_model.*
import std.unittest.*
import std.unittest.testmacro.*

public interface SchemaMarker {}
public interface BoundedMarker {}

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
public struct DerivedInnerSchema <: SchemaMarker {
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

@PostcardSchema
public struct DerivedGenericSchema<T> {
    public let value: T
    public let sample: Option<T>

    public init(value: T, sample: Option<T>) {
        this.value = value
        this.sample = sample
    }
}

@PostcardSchema
public struct DerivedGenericSchemaPair<T, U> {
    public let first: T
    public let second: U

    public init(first: T, second: U) {
        this.first = first
        this.second = second
    }
}

@PostcardSchema
public enum DerivedGenericSchemaCommand<T, U> {
    | Idle
    | One(T)
    | Pair(T, U)
}

@PostcardSchema
public struct DerivedConstrainedSchema<T> where T <: SchemaMarker {
    public let value: T

    public init(value: T) {
        this.value = value
    }
}

@PostcardSchema
public enum DerivedConstrainedSchemaCommand<T> where T <: SchemaMarker {
    | Idle
    | Value(T)
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
public struct DerivedBoundedInner <: BoundedMarker {
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
public struct DerivedGenericBounded<T> {
    public let value: T
    public let sample: Option<T>

    public init(value: T, sample: Option<T>) {
        this.value = value
        this.sample = sample
    }
}

@PostcardMaxSize
public struct DerivedGenericBoundedPair<T, U> {
    public let first: T
    public let second: U

    public init(first: T, second: U) {
        this.first = first
        this.second = second
    }
}

@PostcardMaxSize
public enum DerivedBoundedCommand {
    | Ping
    | SetSpeed(UInt16)
    | Rename(UInt32, Bool)
}

@PostcardMaxSize
public enum DerivedGenericBoundedCommand<T, U> {
    | Idle
    | One(T)
    | Pair(T, U)
}

@PostcardMaxSize
public struct DerivedConstrainedBounded<T> where T <: BoundedMarker {
    public let value: T

    public init(value: T) {
        this.value = value
    }
}

@PostcardMaxSize
public enum DerivedConstrainedBoundedCommand<T> where T <: BoundedMarker {
    | Idle
    | Value(T)
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
    public func genericStructAddsSchemaBounds(): Unit {
        @Assert(
            formatSchema(DerivedGenericSchema<DerivedInnerSchema>.schema()),
            "struct DerivedGenericSchema { value: DerivedInnerSchema, sample: Option<DerivedInnerSchema> }"
        )
    }

    @TestCase
    public func multipleGenericParametersAddIndependentSchemaBounds(): Unit {
        @Assert(
            formatSchema(DerivedGenericSchemaPair<DerivedInnerSchema, DerivedOuterSchema>.schema()),
            "struct DerivedGenericSchemaPair { first: DerivedInnerSchema, second: DerivedOuterSchema }"
        )
    }

    @TestCase
    public func genericEnumAddsIndependentSchemaBounds(): Unit {
        @Assert(
            formatSchema(DerivedGenericSchemaCommand<DerivedInnerSchema, DerivedOuterSchema>.schema()),
            "enum DerivedGenericSchemaCommand { Idle, One(DerivedInnerSchema), Pair(DerivedInnerSchema, DerivedOuterSchema) }"
        )
    }

    @TestCase
    public func generatedSchemasPreserveDeclaredWhereConstraints(): Unit {
        @Assert(
            formatSchema(DerivedConstrainedSchema<DerivedInnerSchema>.schema()),
            "struct DerivedConstrainedSchema { value: DerivedInnerSchema }"
        )
        @Assert(
            formatSchema(DerivedConstrainedSchemaCommand<DerivedInnerSchema>.schema()),
            "enum DerivedConstrainedSchemaCommand { Idle, Value(DerivedInnerSchema) }"
        )
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
        @Assert(DerivedBoundedRecord.postcardMaxSize(), 15)
    }

    @TestCase
    public func nestedTypeUsesNestedMaximum(): Unit {
        @Assert(DerivedBoundedInner.postcardMaxSize(), 3)
        @Assert(DerivedBoundedOuter.postcardMaxSize(), 4)
    }

    @TestCase
    public func genericStructAddsMaximumSizeBounds(): Unit {
        @Assert(DerivedGenericBounded<DerivedBoundedInner>.postcardMaxSize(), 7)
    }

    @TestCase
    public func multipleGenericParametersAddIndependentMaximumSizeBounds(): Unit {
        @Assert(
            DerivedGenericBoundedPair<DerivedBoundedInner, DerivedBoundedOuter>.postcardMaxSize(),
            7
        )
    }

    @TestCase
    public func enumAddsDiscriminantToLargestPayload(): Unit {
        @Assert(DerivedBoundedCommand.postcardMaxSize(), 7)
    }

    @TestCase
    public func genericEnumUsesLargestBoundedPayload(): Unit {
        @Assert(
            DerivedGenericBoundedCommand<DerivedBoundedInner, DerivedBoundedOuter>.postcardMaxSize(),
            8
        )
    }

    @TestCase
    public func generatedMaxSizesPreserveDeclaredWhereConstraints(): Unit {
        @Assert(DerivedConstrainedBounded<DerivedBoundedInner>.postcardMaxSize(), 3)
        @Assert(DerivedConstrainedBoundedCommand<DerivedBoundedInner>.postcardMaxSize(), 4)
    }
}

package postcard4cj.derive_ng_test

import postcard4cj.derive_ng.*
import postcard4cj.max_size.*
import postcard4cj.schema.*
import postcard4cj.schema_ng.*
import postcard4cj.serde_model.*
import std.unittest.*
import std.unittest.testmacro.*

public interface NgSchemaMarker {}
public interface NgBoundedMarker {}

@PostcardSchemaNg
public struct NgInner <: NgSchemaMarker {
    public let code: UInt16

    public init(code: UInt16) {
        this.code = code
    }
}

@PostcardSchemaNg
public struct NgRecord {
    public let id: UInt32
    public let inner: NgInner
    public let note: Option<String>

    public init(id: UInt32, inner: NgInner, note: Option<String>) {
        this.id = id
        this.inner = inner
        this.note = note
    }
}

@PostcardSchemaNg
public struct NgGenericRecord<T> {
    public let value: T
    public let sample: Option<T>

    public init(value: T, sample: Option<T>) {
        this.value = value
        this.sample = sample
    }
}

@PostcardSchemaNg
public struct NgGenericRecordPair<T, U> {
    public let first: T
    public let second: U

    public init(first: T, second: U) {
        this.first = first
        this.second = second
    }
}

@PostcardSchemaNg
public enum NgCommand {
    | Ping
    | Set(UInt16)
    | Pair(UInt8, Bool)
}

@PostcardSchemaNg
public enum NgGenericCommand<T, U> {
    | Idle
    | One(T)
    | Pair(T, U)
}

@PostcardSchemaNg
public struct NgConstrainedRecord<T> where T <: NgSchemaMarker {
    public let value: T

    public init(value: T) {
        this.value = value
    }
}

@PostcardSchemaNg
public enum NgConstrainedCommand<T> where T <: NgSchemaMarker {
    | Idle
    | Value(T)
}

@PostcardMaxSizeNg
public struct NgBoundedInner <: NgBoundedMarker {
    public let code: UInt16

    public init(code: UInt16) {
        this.code = code
    }
}

@PostcardMaxSizeNg
public struct NgBoundedRecord {
    public let id: UInt32
    public let inner: NgBoundedInner
    public let active: Bool

    public init(id: UInt32, inner: NgBoundedInner, active: Bool) {
        this.id = id
        this.inner = inner
        this.active = active
    }
}

@PostcardMaxSizeNg
public struct NgGenericBounded<T> {
    public let value: T
    public let sample: Option<T>

    public init(value: T, sample: Option<T>) {
        this.value = value
        this.sample = sample
    }
}

@PostcardMaxSizeNg
public struct NgGenericBoundedPair<T, U> {
    public let first: T
    public let second: U

    public init(first: T, second: U) {
        this.first = first
        this.second = second
    }
}

@PostcardMaxSizeNg
public enum NgBoundedCommand {
    | Ping
    | Set(UInt16)
    | Pair(UInt32, Bool)
}

@PostcardMaxSizeNg
public enum NgGenericBoundedCommand<T, U> {
    | Idle
    | One(T)
    | Pair(T, U)
}

@PostcardMaxSizeNg
public struct NgConstrainedBounded<T> where T <: NgBoundedMarker {
    public let value: T

    public init(value: T) {
        this.value = value
    }
}

@PostcardMaxSizeNg
public enum NgConstrainedBoundedCommand<T> where T <: NgBoundedMarker {
    | Idle
    | Value(T)
}

@Test
public class NextGenerationSchemaDeriveTest {
    @TestCase
    public func ngStructUsesDistinctInterface(): Unit {
        @Assert(
            formatSchema(NgRecord.schemaNg()),
            "struct NgRecord { id: u32, inner: NgInner, note: Option<String> }"
        )
        @Assert(formatSchema(schemaNgOf<NgRecord>()), formatSchema(NgRecord.schemaNg()))
    }

    @TestCase
    public func ngGenericStructAddsSchemaBounds(): Unit {
        @Assert(
            formatSchema(NgGenericRecord<NgInner>.schemaNg()),
            "struct NgGenericRecord { value: NgInner, sample: Option<NgInner> }"
        )
    }

    @TestCase
    public func ngMultipleGenericParametersAddIndependentSchemaBounds(): Unit {
        @Assert(
            formatSchema(NgGenericRecordPair<NgInner, NgRecord>.schemaNg()),
            "struct NgGenericRecordPair { first: NgInner, second: NgRecord }"
        )
    }

    @TestCase
    public func ngEnumMatchesLegacyWireModel(): Unit {
        @Assert(
            formatSchema(NgCommand.schemaNg()),
            "enum NgCommand { Ping, Set(u16), Pair(u8, bool) }"
        )
        let bytes = toByteArray<NamedType>(NgCommand.schemaNg())
        @Assert(formatSchema(fromByteArray<NamedType>(bytes)), formatSchema(NgCommand.schemaNg()))
    }

    @TestCase
    public func ngGenericEnumAddsIndependentSchemaBounds(): Unit {
        @Assert(
            formatSchema(NgGenericCommand<NgInner, NgRecord>.schemaNg()),
            "enum NgGenericCommand { Idle, One(NgInner), Pair(NgInner, NgRecord) }"
        )
    }

    @TestCase
    public func ngGeneratedSchemasPreserveDeclaredWhereConstraints(): Unit {
        @Assert(
            formatSchema(NgConstrainedRecord<NgInner>.schemaNg()),
            "struct NgConstrainedRecord { value: NgInner }"
        )
        @Assert(
            formatSchema(NgConstrainedCommand<NgInner>.schemaNg()),
            "enum NgConstrainedCommand { Idle, Value(NgInner) }"
        )
    }

    @TestCase
    public func ngKeyUsesSameStableHashAlgorithm(): Unit {
        @Assert(
            keyForPathNg<NgRecord>("/ng").constCompare(
                keyForSchemaPath("/ng", NgRecord.schemaNg())
            ),
            true
        )
    }
}

@Test
public class NextGenerationMaxSizeDeriveTest {
    @TestCase
    public func ngStructSumsNestedBounds(): Unit {
        @Assert(NgBoundedInner.postcardMaxSize(), 3)
        @Assert(NgBoundedRecord.postcardMaxSize(), 9)
    }

    @TestCase
    public func ngGenericStructAddsMaximumSizeBounds(): Unit {
        @Assert(NgGenericBounded<NgBoundedInner>.postcardMaxSize(), 7)
    }

    @TestCase
    public func ngMultipleGenericParametersAddIndependentMaximumSizeBounds(): Unit {
        @Assert(
            NgGenericBoundedPair<NgBoundedInner, NgBoundedRecord>.postcardMaxSize(),
            12
        )
    }

    @TestCase
    public func ngEnumUsesLargestPayload(): Unit {
        @Assert(NgBoundedCommand.postcardMaxSize(), 7)
    }

    @TestCase
    public func ngGenericEnumUsesLargestBoundedPayload(): Unit {
        @Assert(
            NgGenericBoundedCommand<NgBoundedInner, NgBoundedRecord>.postcardMaxSize(),
            13
        )
    }

    @TestCase
    public func ngGeneratedMaxSizesPreserveDeclaredWhereConstraints(): Unit {
        @Assert(NgConstrainedBounded<NgBoundedInner>.postcardMaxSize(), 3)
        @Assert(NgConstrainedBoundedCommand<NgBoundedInner>.postcardMaxSize(), 4)
    }
}

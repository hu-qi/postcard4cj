package postcard4cj.derive_ng_test

import postcard4cj.derive_ng.*
import postcard4cj.max_size.*
import postcard4cj.schema.*
import postcard4cj.schema_ng.*
import postcard4cj.serde_model.*
import std.unittest.*
import std.unittest.testmacro.*

@PostcardSchemaNg
public struct NgInner {
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
public enum NgCommand {
    | Ping
    | Set(UInt16)
    | Pair(UInt8, Bool)
}

@PostcardMaxSizeNg
public struct NgBoundedInner {
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
public enum NgBoundedCommand {
    | Ping
    | Set(UInt16)
    | Pair(UInt32, Bool)
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
    public func ngEnumMatchesLegacyWireModel(): Unit {
        @Assert(
            formatSchema(NgCommand.schemaNg()),
            "enum NgCommand { Ping, Set(u16), Pair(u8, bool) }"
        )
        let bytes = toByteArray<NamedType>(NgCommand.schemaNg())
        @Assert(formatSchema(fromByteArray<NamedType>(bytes)), formatSchema(NgCommand.schemaNg()))
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
    public func ngEnumUsesLargestPayload(): Unit {
        @Assert(NgBoundedCommand.postcardMaxSize(), 7)
    }
}

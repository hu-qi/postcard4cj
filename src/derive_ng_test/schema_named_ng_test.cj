package postcard4cj.derive_ng_test

import postcard4cj.derive_ng.*
import postcard4cj.schema.*
import std.unittest.*
import std.unittest.testmacro.*

@PostcardSchemaNgNamed["ng_wire_record", "id=wire_id", "note=message"]
public struct NgNamedSchemaRecord {
    public let id: UInt32
    public let note: Option<String>

    public init(id: UInt32, note: Option<String>) {
        this.id = id
        this.note = note
    }
}

@PostcardSchemaNgNamed["ng_wire_command", "Ping=ping", "Set=set_value"]
public enum NgNamedSchemaCommand {
    | Ping
    | Set(UInt16)
}

@Test
public class PostcardSchemaNgNamedTest {
    @TestCase
    public func renamesNgTypeAndStructFields(): Unit {
        @Assert(
            formatSchema(NgNamedSchemaRecord.schemaNg()),
            "struct ng_wire_record { wire_id: u32, message: Option<String> }"
        )
    }

    @TestCase
    public func renamesNgTypeAndEnumVariants(): Unit {
        @Assert(
            formatSchema(NgNamedSchemaCommand.schemaNg()),
            "enum ng_wire_command { ping, set_value(u16) }"
        )
    }
}

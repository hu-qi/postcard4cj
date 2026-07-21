package postcard4cj.postcard_macro_test

import postcard4cj.postcard_macro.*
import postcard4cj.schema.*
import std.unittest.*
import std.unittest.testmacro.*

@PostcardSchemaNamed["wire_record", "id=wire_id", "note=message"]
public struct NamedSchemaRecord {
    public let id: UInt32
    public let note: Option<String>

    public init(id: UInt32, note: Option<String>) {
        this.id = id
        this.note = note
    }
}

@PostcardSchemaNamed["wire_command", "Ping=ping", "SetSpeed=set_speed"]
public enum NamedSchemaCommand {
    | Ping
    | SetSpeed(UInt16)
}

@Test
public class PostcardSchemaNamedTest {
    @TestCase
    public func renamesTypeAndStructFields(): Unit {
        @Assert(
            formatSchema(NamedSchemaRecord.schema()),
            "struct wire_record { wire_id: u32, message: Option<String> }"
        )
    }

    @TestCase
    public func renamesTypeAndEnumVariants(): Unit {
        @Assert(
            formatSchema(NamedSchemaCommand.schema()),
            "enum wire_command { ping, set_speed(u16) }"
        )
    }
}

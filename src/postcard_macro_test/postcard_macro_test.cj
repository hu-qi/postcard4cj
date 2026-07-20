package postcard4cj.postcard_macro_test

import postcard4cj.*
import postcard4cj.postcard_macro.*
import std.math.numeric.*
import std.unittest.*
import std.unittest.testmacro.*

@Postcard
public struct MacroRecord {
    public let id: UInt32
    public let delta: Int32
    public let note: Option<String>
    public let values: Array<UInt16>
    public init(id: UInt32, delta: Int32, note: Option<String>, values: Array<UInt16>) {
        this.id = id
        this.delta = delta
        this.note = note
        this.values = values
    }
}

@Postcard
public struct MacroWide {
    public let unsigned: PostcardUInt128
    public let signed: PostcardInt128
    public init(unsigned: PostcardUInt128, signed: PostcardInt128) {
        this.unsigned = unsigned
        this.signed = signed
    }
}

@Postcard
public enum MacroCommand {
    | Ping
    | SetSpeed(UInt16)
    | Rename(String, Bool)
}

@Test
public class PostcardMacroTest {
    @TestCase
    public func generatedStructCodecMatchesRustWireFormat(): Unit {
        let value = MacroRecord(42u32,-1i32,Some("Hi"),[1u16,128u16])
        let expected: Array<UInt8> = [0x2au8,0x01u8,0x01u8,0x02u8,0x48u8,0x69u8,0x02u8,0x01u8,0x80u8,0x01u8]
        @Assert(toBytes<MacroRecord>(value),expected)
        let decoded = fromBytes<MacroRecord>(expected)
        @Assert(decoded.id,42u32)
        @Assert(decoded.delta,-1i32)
        @Assert(decoded.note,Some("Hi"))
        @Assert(decoded.values,[1u16,128u16])
    }

    @TestCase
    public func generatedStructSupportsTypedInt128Wrappers(): Unit {
        let value = MacroWide(PostcardUInt128(BigInt(128i64)),PostcardInt128(BigInt(-1i64)))
        let expected: Array<UInt8> = [0x80u8,0x01u8,0x01u8]
        @Assert(toBytes<MacroWide>(value),expected)
        let decoded = fromBytes<MacroWide>(expected)
        @Assert(decoded.unsigned.value,BigInt(128i64))
        @Assert(decoded.signed.value,BigInt(-1i64))
    }

    @TestCase
    public func generatedEnumCodecUsesDeclarationOrder(): Unit {
        @Assert(toBytes<MacroCommand>(MacroCommand.Ping),[0x00u8])
        @Assert(toBytes<MacroCommand>(MacroCommand.SetSpeed(128u16)),[0x01u8,0x80u8,0x01u8])
        @Assert(toBytes<MacroCommand>(MacroCommand.Rename("Hi",true)),[0x02u8,0x02u8,0x48u8,0x69u8,0x01u8])
        let speed = fromBytes<MacroCommand>([0x01u8,0x80u8,0x01u8])
        match (speed) { case MacroCommand.SetSpeed(value) => @Assert(value,128u16); case _ => throw IllegalStateException("Decoded the wrong MacroCommand variant") }
        let renamed = fromBytes<MacroCommand>([0x02u8,0x02u8,0x48u8,0x69u8,0x01u8])
        match (renamed) { case MacroCommand.Rename(name,enabled) => @Assert(name,"Hi"); @Assert(enabled,true); case _ => throw IllegalStateException("Decoded the wrong MacroCommand payload") }
    }
}

package postcard4cj

import std.unittest.*
import std.unittest.testmacro.*

private struct FixedRecord <: PostcardEncode {
    private let id: UInt32
    private let delta: Int32
    private let active: Bool
    private let name: String

    public init(id: UInt32, delta: Int32, active: Bool, name: String) {
        this.id = id
        this.delta = delta
        this.active = active
        this.name = name
    }

    public func encode(encoder: PostcardEncoder): Unit {
        encoder.writeUInt32(id)
        encoder.writeInt32(delta)
        encoder.writeBool(active)
        encoder.writeString(name)
    }
}

@Test
public class PostcardFixedBufferTest {
    private let value = FixedRecord(42u32,-1i32,true,"Hi")
    private let expected: Array<UInt8> = [0x2au8,0x01u8,0x01u8,0x02u8,0x48u8,0x69u8]

    @TestCase
    public func exactCapacityWritesInPlace(): Unit {
        let buffer = Array<UInt8>(expected.size, repeat: 0xeeu8)
        let used = encodeTo<FixedRecord>(value, buffer)
        @Assert(used, expected.size)
        @Assert(buffer, expected)
    }

    @TestCase
    public func largerBufferPreservesUnusedTail(): Unit {
        let buffer = Array<UInt8>(10, repeat: 0xeeu8)
        let used = encodeTo<FixedRecord>(value, buffer)
        @Assert(used, expected.size)
        @Assert(buffer[0..used], expected)
        @Assert(buffer[used..buffer.size], [0xeeu8,0xeeu8,0xeeu8,0xeeu8])
    }

    @TestCase
    public func insufficientCapacityFailsImmediately(): Unit {
        let buffer = Array<UInt8>(expected.size - 1, repeat: 0u8)
        @AssertThrows[IllegalArgumentException](encodeTo<FixedRecord>(value, buffer))
    }
}

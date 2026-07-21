package postcard4cj.compatibility

import postcard4cj.*
import std.unittest.*
import std.unittest.testmacro.*

private func appendTail(message: Array<UInt8>, tail: Array<UInt8>): Array<UInt8> {
    let output = Array<UInt8>(message.size + tail.size, repeat: 0u8)
    var index = 0i64
    while (index < message.size) {
        output[index] = message[index]
        index++
    }
    var tailIndex = 0i64
    while (tailIndex < tail.size) {
        output[message.size + tailIndex] = tail[tailIndex]
        tailIndex++
    }
    return output
}

@Test
public class PureCangjieRemainderCompatibilityTest {
    @TestCase
    public func cobsHelperReturnsBytesAfterFirstFrame(): Unit {
        let value = CompatibilityRecord(1u32, -1i32, true, "x")
        let frame = toBytesCobs<CompatibilityRecord>(value)
        let input = appendTail(frame, [0xaau8, 0xbbu8])
        let result = takeFromBytesCobs<CompatibilityRecord>(input)

        @Assert(result[0].id, value.id)
        @Assert(result[0].delta, value.delta)
        @Assert(result[0].active, value.active)
        @Assert(result[0].name, value.name)
        @Assert(result[1], [0xaau8, 0xbbu8])
    }

    @TestCase
    public func crcHelperReturnsBytesAfterValidatedTrailer(): Unit {
        let value = CompatibilityRecord(1u32, -1i32, true, "x")
        let message = toBytesCrc32Iscsi<CompatibilityRecord>(value)
        let input = appendTail(message, [0xccu8, 0xddu8])
        let result = takeFromBytesCrc32Iscsi<CompatibilityRecord>(input)

        @Assert(result[0].id, value.id)
        @Assert(result[0].delta, value.delta)
        @Assert(result[0].active, value.active)
        @Assert(result[0].name, value.name)
        @Assert(result[1], [0xccu8, 0xddu8])
    }
}

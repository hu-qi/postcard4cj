package postcard4cj.compatibility

import postcard4cj.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class PureCangjieRemainderCompatibilityTest {
    @TestCase
    public func cobsHelperReturnsBytesAfterFirstFrame(): Unit {
        let value = CompatibilityRecord(1u32, -1i32, true, "x")
        let frame = toBytesCobs<CompatibilityRecord>(value)
        let input = frame + [0xaau8, 0xbbu8]
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
        let input = message + [0xccu8, 0xddu8]
        let result = takeFromBytesCrc32Iscsi<CompatibilityRecord>(input)

        @Assert(result[0].id, value.id)
        @Assert(result[0].delta, value.delta)
        @Assert(result[0].active, value.active)
        @Assert(result[0].name, value.name)
        @Assert(result[1], [0xccu8, 0xddu8])
    }
}

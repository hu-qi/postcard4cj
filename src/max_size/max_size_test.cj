package postcard4cj.max_size

import std.unittest.*
import std.unittest.testmacro.*

public struct MaxByte <: PostcardMaxSize {
    public static func postcardMaxSize(): Int64 { return uint8MaxSize() }
}

public struct MaxWord <: PostcardMaxSize {
    public static func postcardMaxSize(): Int64 { return uint32MaxSize() }
}

public struct MaxRecord <: PostcardMaxSize {
    public static func postcardMaxSize(): Int64 {
        return uint32MaxSize() + boolMaxSize() + stringMaxSize(10)
    }
}

@Test
public class MaximumSizeTest {
    @TestCase
    public func primitiveMaximumsMatchPostcardVarints(): Unit {
        @Assert(boolMaxSize(), 1)
        @Assert(int8MaxSize(), 1)
        @Assert(uint16MaxSize(), 3)
        @Assert(uint32MaxSize(), 5)
        @Assert(uint64MaxSize(), 10)
        @Assert(uint128MaxSize(), 19)
        @Assert(float32MaxSize(), 4)
        @Assert(float64MaxSize(), 8)
        @Assert(runeMaxSize(), 5)
        @Assert(unitMaxSize(), 0)
    }

    @TestCase
    public func specificVarintSizesRoundUpCanonically(): Unit {
        @Assert(varintSize(0u64), 1)
        @Assert(varintSize(127u64), 1)
        @Assert(varintSize(128u64), 2)
        @Assert(varintSize(16383u64), 2)
        @Assert(varintSize(16384u64), 3)
    }

    @TestCase
    public func optionResultTupleAndArrayBounds(): Unit {
        @Assert(optionMaxSize<MaxWord>(), 6)
        @Assert(resultMaxSize<MaxByte, MaxWord>(), 6)
        @Assert(tuple2MaxSize<MaxByte, MaxWord>(), 6)
        @Assert(fixedArrayMaxSize<MaxWord>(4), 20)
    }

    @TestCase
    public func boundedCollectionsIncludeLengthPrefix(): Unit {
        @Assert(sequenceMaxSize<MaxWord>(3), 16)
        @Assert(stringMaxSize(10), 11)
        @Assert(mapMaxSize<MaxByte, MaxWord>(2), 13)
    }

    @TestCase
    public func enumMapUsesEnumBackingFixedArrayMaximum(): Unit {
        @Assert(enumMapMaxSize<MaxWord>(3), 15)
        @AssertThrows[IllegalArgumentException](enumMapMaxSize<MaxWord>(-1))
    }

    @TestCase
    public func enumUsesLargestPayloadAndLargestIndex(): Unit {
        @Assert(enumMaxSize(2u32, 10), 11)
        @Assert(enumMaxSize(128u32, 10), 12)
    }

    @TestCase
    public func userTypeExposesStaticMaximum(): Unit {
        @Assert(maxSizeOf<MaxRecord>(), 17)
    }
}

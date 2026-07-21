package postcard4cj.benchmark

import postcard4cj.*
import std.unittest.*
import std.unittest.testmacro.*

public struct BenchmarkRecord <: PostcardEncode & PostcardDecode<BenchmarkRecord> {
    public let id: UInt32
    public let delta: Int32
    public let active: Bool
    public let name: String
    public let samples: Array<Int16>

    public init(id: UInt32, delta: Int32, active: Bool, name: String, samples: Array<Int16>) {
        this.id = id
        this.delta = delta
        this.active = active
        this.name = name
        this.samples = samples
    }

    public func encode(encoder: PostcardEncoder): Unit {
        encoder.writeUInt32(id)
        encoder.writeInt32(delta)
        encoder.writeBool(active)
        encoder.writeString(name)
        encoder.writeSequence<Int16>(samples, {value: Int16 => encoder.writeInt16(value)})
    }

    public static func decode(decoder: PostcardDecoder): BenchmarkRecord {
        return BenchmarkRecord(
            decoder.readUInt32(),
            decoder.readInt32(),
            decoder.readBool(),
            decoder.readString(),
            decoder.readSequence<Int16>({=> decoder.readInt16()})
        )
    }
}

@Test
public class PostcardBenchmarks {
    private let value = BenchmarkRecord(
        300u32,
        -12345i32,
        true,
        "postcard4cj benchmark payload",
        Array<Int16>(128, {index: Int64 => Int16(index - 64)})
    )
    private let plain: Array<UInt8>
    private let cobs: Array<UInt8>
    private let crc: Array<UInt8>
    private var sink: Int64 = 0

    public init() {
        plain = toBytes<BenchmarkRecord>(value)
        cobs = toBytesCobs<BenchmarkRecord>(value)
        crc = toBytesCrc32Iscsi<BenchmarkRecord>(value)
    }

    @Bench
    public func encodePlain(): Unit {
        sink = toBytes<BenchmarkRecord>(value).size
    }

    @Bench
    public func decodePlain(): Unit {
        sink = Int64(fromBytes<BenchmarkRecord>(plain).id)
    }

    @Bench
    public func encodeCobs(): Unit {
        sink = toBytesCobs<BenchmarkRecord>(value).size
    }

    @Bench
    public func decodeCobs(): Unit {
        sink = Int64(fromBytesCobs<BenchmarkRecord>(cobs).id)
    }

    @Bench
    public func encodeCrc32c(): Unit {
        sink = toBytesCrc32Iscsi<BenchmarkRecord>(value).size
    }

    @Bench
    public func decodeCrc32c(): Unit {
        sink = Int64(fromBytesCrc32Iscsi<BenchmarkRecord>(crc).id)
    }
}

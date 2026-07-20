package postcard4cj

import std.math.numeric.*

public struct PostcardUInt128 <: PostcardEncode & PostcardDecode<PostcardUInt128> {
    public let value: BigInt

    public init(value: BigInt) {
        encodeUInt128(value)
        this.value = value
    }

    public func encode(encoder: PostcardEncoder): Unit {
        encoder.writeUInt128(value)
    }

    public static func decode(decoder: PostcardDecoder): PostcardUInt128 {
        return PostcardUInt128(decoder.readUInt128())
    }
}

public struct PostcardInt128 <: PostcardEncode & PostcardDecode<PostcardInt128> {
    public let value: BigInt

    public init(value: BigInt) {
        zigZagEncodeInt128(value)
        this.value = value
    }

    public func encode(encoder: PostcardEncoder): Unit {
        encoder.writeInt128(value)
    }

    public static func decode(decoder: PostcardDecoder): PostcardInt128 {
        return PostcardInt128(decoder.readInt128())
    }
}

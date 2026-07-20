package postcard4cj.v2_fixed

import postcard4cj.core.*
import postcard4cj.flavors.*
import postcard4cj.serde_model.*
import postcard4cj.v2.*

/** Runtime-capacity Cangjie substitute for heapless::Vec<u8, B>. */
public class FixedByteVec {
    private let storage: Array<UInt8>
    private var used: Int64

    public init(capacity: Int64) {
        if (capacity < 0) {
            throw IllegalArgumentException("FixedByteVec capacity cannot be negative")
        }
        storage = Array<UInt8>(capacity, repeat: 0u8)
        used = 0
    }

    public func capacity(): Int64 {
        return storage.size
    }

    public func size(): Int64 {
        return used
    }

    public func remaining(): Int64 {
        return storage.size - used
    }

    public func push(value: UInt8): Unit {
        if (used >= storage.size) {
            throw PostcardException(
                PostcardErrorKind.SerializeBufferFull,
                "FixedByteVec is full"
            )
        }
        storage[used] = value
        used++
    }

    public func appendBytes(values: Array<UInt8>): Unit {
        if (values.size > remaining()) {
            throw PostcardException(
                PostcardErrorKind.SerializeBufferFull,
                "FixedByteVec is full"
            )
        }
        for (value in values) {
            storage[used] = value
            used++
        }
    }

    public func get(index: Int64): UInt8 {
        if (index < 0 || index >= used) {
            throw IndexOutOfBoundsException("FixedByteVec index is outside used data")
        }
        return storage[index]
    }

    public func set(index: Int64, value: UInt8): Unit {
        if (index < 0 || index >= used) {
            throw IndexOutOfBoundsException("FixedByteVec index is outside used data")
        }
        storage[index] = value
    }

    public func toArray(): Array<UInt8> {
        return storage[..used]
    }
}

public class FixedVecFlavor <: SerializeFlavor {
    private let value: FixedByteVec

    public init(capacity: Int64) {
        value = FixedByteVec(capacity)
    }

    public init(value: FixedByteVec) {
        this.value = value
    }

    public func vector(): FixedByteVec {
        return value
    }

    public func tryPush(data: UInt8): Unit {
        value.push(data)
    }

    public func tryExtend(data: Array<UInt8>): Unit {
        value.appendBytes(data)
    }

    public func position(): Int64 {
        return value.size()
    }

    public func snapshot(): Array<UInt8> {
        return value.toArray()
    }

    public func finalize(): Array<UInt8> {
        return value.toArray()
    }
}

public func toFixedVecV2<T>(value: T, capacity: Int64): FixedByteVec
    where T <: PostcardSerialize {
    let flavor = FixedVecFlavor(capacity)
    let serializer = Serializer(flavor)
    try {
        value.serialize(serializer)
        serializer.finalize()
        return flavor.vector()
    } catch (error: PostcardException) {
        throw SerializerException(SerializerErrorKind.PushError, error.message)
    }
}

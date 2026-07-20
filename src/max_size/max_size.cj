package postcard4cj.max_size

/** Types with a statically known maximum unflavored Postcard size. */
public interface PostcardMaxSize {
    static func postcardMaxSize(): Int64
}

/** Maximum number of bytes for a Varint carrying the given bit width. */
public func varintMaximum(bits: Int64): Int64 {
    if (bits <= 0) {
        return 1
    }
    return (bits + 6) / 7
}

/** Number of Varint bytes required to encode a specific non-negative value. */
public func varintSize(value: UInt64): Int64 {
    var current = value
    var bytes = 1i64
    while (current >= 0x80u64) {
        current >>= 7
        bytes++
    }
    return bytes
}

public func boolMaxSize(): Int64 { return 1 }
public func int8MaxSize(): Int64 { return 1 }
public func int16MaxSize(): Int64 { return varintMaximum(16) }
public func int32MaxSize(): Int64 { return varintMaximum(32) }
public func int64MaxSize(): Int64 { return varintMaximum(64) }
public func int128MaxSize(): Int64 { return varintMaximum(128) }
public func uint8MaxSize(): Int64 { return 1 }
public func uint16MaxSize(): Int64 { return varintMaximum(16) }
public func uint32MaxSize(): Int64 { return varintMaximum(32) }
public func uint64MaxSize(): Int64 { return varintMaximum(64) }
public func uint128MaxSize(): Int64 { return varintMaximum(128) }
public func platformIntMaxSize(): Int64 { return int64MaxSize() }
public func platformUIntMaxSize(): Int64 { return uint64MaxSize() }
public func float32MaxSize(): Int64 { return 4 }
public func float64MaxSize(): Int64 { return 8 }
/** A Rune is encoded as one length byte plus at most four UTF-8 bytes. */
public func runeMaxSize(): Int64 { return 5 }
public func unitMaxSize(): Int64 { return 0 }

public func maxSizeOf<T>(): Int64 where T <: PostcardMaxSize {
    return T.postcardMaxSize()
}

public func optionMaxSize<T>(): Int64 where T <: PostcardMaxSize {
    return 1 + T.postcardMaxSize()
}

public func resultMaxSize<T, E>(): Int64
    where T <: PostcardMaxSize, E <: PostcardMaxSize {
    let success = T.postcardMaxSize()
    let failure = E.postcardMaxSize()
    return 1 + if (success > failure) { success } else { failure }
}

/** Fixed arrays and tuples have no container header. */
public func fixedArrayMaxSize<T>(length: Int64): Int64 where T <: PostcardMaxSize {
    if (length < 0) {
        throw IllegalArgumentException("Array length cannot be negative")
    }
    return length * T.postcardMaxSize()
}

/** Bounded dynamic sequences include the maximum length prefix. */
public func sequenceMaxSize<T>(capacity: Int64): Int64 where T <: PostcardMaxSize {
    if (capacity < 0) {
        throw IllegalArgumentException("Sequence capacity cannot be negative")
    }
    return varintSize(UInt64(capacity)) + capacity * T.postcardMaxSize()
}

/** Bounded strings include a byte-length prefix and their UTF-8 byte capacity. */
public func stringMaxSize(byteCapacity: Int64): Int64 {
    if (byteCapacity < 0) {
        throw IllegalArgumentException("String capacity cannot be negative")
    }
    return varintSize(UInt64(byteCapacity)) + byteCapacity
}

public func tuple2MaxSize<A, B>(): Int64
    where A <: PostcardMaxSize, B <: PostcardMaxSize {
    return A.postcardMaxSize() + B.postcardMaxSize()
}

public func tuple3MaxSize<A, B, C>(): Int64
    where A <: PostcardMaxSize, B <: PostcardMaxSize, C <: PostcardMaxSize {
    return A.postcardMaxSize() + B.postcardMaxSize() + C.postcardMaxSize()
}

public func mapMaxSize<K, V>(capacity: Int64): Int64
    where K <: PostcardMaxSize, V <: PostcardMaxSize {
    if (capacity < 0) {
        throw IllegalArgumentException("Map capacity cannot be negative")
    }
    return varintSize(UInt64(capacity)) +
        capacity * (K.postcardMaxSize() + V.postcardMaxSize())
}

/** Enum maximum: discriminant plus the largest variant payload. */
public func enumMaxSize(maxVariantIndex: UInt32, largestPayload: Int64): Int64 {
    if (largestPayload < 0) {
        throw IllegalArgumentException("Enum payload size cannot be negative")
    }
    return varintSize(UInt64(maxVariantIndex)) + largestPayload
}

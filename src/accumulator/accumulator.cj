package postcard4cj.accumulator

import postcard4cj.flavors.*
import postcard4cj.serde_model.*

/** Result of feeding chunked COBS data into an accumulator. */
public enum FeedResult<T> {
    | Consumed
    | OverFull(Array<UInt8>)
    | DeserError(Array<UInt8>)
    | Success(T, Array<UInt8>)
}

/**
 * Collects chunked zero-terminated COBS frames and deserializes complete values.
 *
 * Cangjie uses a runtime capacity instead of Rust const generics. The behavior
 * and remainder semantics follow postcard::accumulator::CobsAccumulator.
 */
public class CobsAccumulator {
    private let buffer: Array<UInt8>
    private var index: Int64

    public init(capacity: Int64) {
        if (capacity <= 0) {
            throw IllegalArgumentException("COBS accumulator capacity must be positive")
        }
        buffer = Array<UInt8>(capacity, repeat: 0u8)
        index = 0
    }

    public func capacity(): Int64 {
        return buffer.size
    }

    public func pending(): Int64 {
        return index
    }

    public func reset(): Unit {
        index = 0
    }

    public func feed<T>(input: Array<UInt8>): FeedResult<T>
        where T <: PostcardDeserialize<T> {
        if (input.size == 0) {
            return FeedResult<T>.Consumed
        }

        var zeroPosition = -1i64
        var scan = 0i64
        while (scan < input.size) {
            if (input[scan] == 0u8) {
                zeroPosition = scan
                break
            }
            scan++
        }

        if (zeroPosition >= 0) {
            let takeLength = zeroPosition + 1
            let remaining = input[takeLength..input.size]

            if (index + takeLength > buffer.size) {
                index = 0
                return FeedResult<T>.OverFull(remaining)
            }

            copyIntoBuffer(input[..takeLength])
            let frame = buffer[..index]
            index = 0

            try {
                let deserializer = Deserializer(CobsDeserializeFlavor(frame))
                let value = T.deserialize(deserializer)
                if (deserializer.finalize().size != 0) {
                    return FeedResult<T>.DeserError(remaining)
                }
                return FeedResult<T>.Success(value, remaining)
            } catch (_: Exception) {
                return FeedResult<T>.DeserError(remaining)
            }
        }

        if (index + input.size > buffer.size) {
            let consumedBeforeOverflow = buffer.size - index
            index = 0
            return FeedResult<T>.OverFull(input[consumedBeforeOverflow..input.size])
        }

        copyIntoBuffer(input)
        return FeedResult<T>.Consumed
    }

    private func copyIntoBuffer(input: Array<UInt8>): Unit {
        for (byte in input) {
            buffer[index] = byte
            index++
        }
    }
}

package postcard4cj.v2_eio

import postcard4cj.core.*
import postcard4cj.flavors.*
import postcard4cj.serde_model.*
import postcard4cj.v2.DeserializerErrorKind
import postcard4cj.v2.DeserializerException
import postcard4cj.v2.SerializerErrorKind
import postcard4cj.v2.SerializerException

/** Cangjie language-level substitute for embedded-io Write. */
public interface ByteWriter {
    func writeAll(data: Array<UInt8>): Unit
    func flush(): Unit
}

/** Cangjie language-level substitute for embedded-io Read. */
public interface ByteReader {
    func readExact(count: Int64): Array<UInt8>
}

/** Streaming serialization Flavor that writes bytes immediately. */
public class WriteFlavor <: SerializeFlavor {
    private let writerValue: ByteWriter
    private var written: Int64

    public init(writer: ByteWriter) {
        writerValue = writer
        written = 0
    }

    public func writer(): ByteWriter {
        return writerValue
    }

    public func tryPush(data: UInt8): Unit {
        try {
            writerValue.writeAll([data])
            written++
        } catch (_: Exception) {
            throw PostcardException(
                PostcardErrorKind.SerializeBufferFull,
                "ByteWriter failed while writing one Postcard byte"
            )
        }
    }

    public func tryExtend(data: Array<UInt8>): Unit {
        try {
            writerValue.writeAll(data)
            written += data.size
        } catch (_: Exception) {
            throw PostcardException(
                PostcardErrorKind.SerializeBufferFull,
                "ByteWriter failed while extending Postcard output"
            )
        }
    }

    public func position(): Int64 {
        return written
    }

    /** Streaming output has no in-memory snapshot. */
    public func snapshot(): Array<UInt8> {
        return []
    }

    public func finalize(): Array<UInt8> {
        try {
            writerValue.flush()
            return []
        } catch (_: Exception) {
            throw PostcardException(
                PostcardErrorKind.SerializeBufferFull,
                "ByteWriter failed while flushing Postcard output"
            )
        }
    }
}

/**
 * Streaming deserialization Flavor with caller-provided temporary storage.
 * Borrowed string/byte views are represented by Array slices retained in scratch.
 */
public class ReaderFlavor <: DeserializeFlavor {
    private let readerValue: ByteReader
    private let scratch: Array<UInt8>
    private var scratchUsed: Int64
    private var bytesRead: Int64

    public init(reader: ByteReader, scratch: Array<UInt8>) {
        readerValue = reader
        this.scratch = scratch
        scratchUsed = 0
        bytesRead = 0
    }

    public func reader(): ByteReader {
        return readerValue
    }

    public func pop(): UInt8 {
        let bytes = readFromSource(1)
        return bytes[0]
    }

    public func tryTake(count: Int64): Array<UInt8> {
        if (count < 0 || count > scratch.size - scratchUsed) {
            throw PostcardException(
                PostcardErrorKind.DeserializeUnexpectedEnd,
                "Temporary EIO buffer is exhausted"
            )
        }
        let bytes = readFromSource(count)
        let start = scratchUsed
        for (byte in bytes) {
            scratch[scratchUsed] = byte
            scratchUsed++
        }
        return scratch[start..scratchUsed]
    }

    public func sizeHint(): Option<Int64> {
        return None
    }

    public func position(): Int64 {
        return bytesRead
    }

    /** Return the unused portion of the caller's temporary buffer. */
    public func finalize(): Array<UInt8> {
        return scratch[scratchUsed..scratch.size]
    }

    public func unusedScratch(): Array<UInt8> {
        return finalize()
    }

    private func readFromSource(count: Int64): Array<UInt8> {
        try {
            let bytes = readerValue.readExact(count)
            if (bytes.size != count) {
                throw IllegalStateException("ByteReader returned a short exact read")
            }
            bytesRead += count
            return bytes
        } catch (_: Exception) {
            throw PostcardException(
                PostcardErrorKind.DeserializeUnexpectedEnd,
                "ByteReader reached the end of the Postcard stream"
            )
        }
    }
}

public class EioDeserializeResult<T> {
    public let value: T
    public let reader: ByteReader
    public let unusedScratch: Array<UInt8>

    public init(value: T, reader: ByteReader, unusedScratch: Array<UInt8>) {
        this.value = value
        this.reader = reader
        this.unusedScratch = unusedScratch
    }
}

/** Serialize through a streaming ByteWriter and return that writer after flush. */
public func toEioV2<T>(value: T, writer: ByteWriter): ByteWriter
    where T <: PostcardSerialize {
    let flavor = WriteFlavor(writer)
    let serializer = Serializer(flavor)
    try {
        value.serialize(serializer)
        serializer.finalize()
        return flavor.writer()
    } catch (error: PostcardException) {
        throw SerializerException(SerializerErrorKind.PushError, error.message)
    }
}

/** Deserialize through a ByteReader using the supplied temporary storage. */
public func fromEioV2<T>(
    reader: ByteReader,
    scratch: Array<UInt8>
): EioDeserializeResult<T> where T <: PostcardDeserialize<T> {
    let flavor = ReaderFlavor(reader, scratch)
    let deserializer = Deserializer(flavor)
    try {
        let value = T.deserialize(deserializer)
        let unused = deserializer.finalize()
        return EioDeserializeResult<T>(value, flavor.reader(), unused)
    } catch (error: PostcardException) {
        throw DeserializerException(DeserializerErrorKind.PopError, error.message)
    }
}

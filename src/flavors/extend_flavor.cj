package postcard4cj.flavors

import postcard4cj.core.*

/** Generic byte collection/sink corresponding to Rust Extend<u8>. */
public interface ByteExtendSink {
    func extend(data: Array<UInt8>): Unit
}

/** Serialization Flavor that forwards bytes directly to a generic sink. */
public class ExtendSerializeFlavor <: SerializeFlavor {
    private let sinkValue: ByteExtendSink
    private var written: Int64

    public init(sink: ByteExtendSink) {
        sinkValue = sink
        written = 0
    }

    public func sink(): ByteExtendSink {
        return sinkValue
    }

    public func tryPush(data: UInt8): Unit {
        try {
            sinkValue.extend([data])
            written++
        } catch (_: Exception) {
            throw PostcardException(
                PostcardErrorKind.SerializeBufferFull,
                "Extend sink rejected a Postcard byte"
            )
        }
    }

    public func tryExtend(data: Array<UInt8>): Unit {
        try {
            sinkValue.extend(data)
            written += data.size
        } catch (_: Exception) {
            throw PostcardException(
                PostcardErrorKind.SerializeBufferFull,
                "Extend sink rejected Postcard bytes"
            )
        }
    }

    public func position(): Int64 {
        return written
    }

    public func snapshot(): Array<UInt8> {
        return []
    }

    public func finalize(): Array<UInt8> {
        return []
    }
}

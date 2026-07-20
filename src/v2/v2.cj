package postcard4cj.v2

import postcard4cj.core.*
import postcard4cj.flavors.*
import postcard4cj.serde_model.*

public enum SerializerErrorKind {
    | PushError
    | FinalizeError
    | SeqLengthUnknown
    | Custom
}

public class SerializerException <: Exception {
    public let kind: SerializerErrorKind

    public init(kind: SerializerErrorKind, message: String) {
        super(message)
        this.kind = kind
    }
}

public enum DeserializerErrorKind {
    | PopError
    | FinalizeError
    | BadBool
    | BadVarint
    | BadChar
    | BadUtf8
    | BadOption
    | UnsupportedDeserAny
    | UnsupportedDeserIdent
    | UnsupportedDeserIgnoredAny
    | Custom
}

public class DeserializerException <: Exception {
    public let kind: DeserializerErrorKind

    public init(kind: DeserializerErrorKind, message: String) {
        super(message)
        this.kind = kind
    }
}

private func mapSerializerError(error: PostcardException): SerializerException {
    return match (error.kind) {
        case PostcardErrorKind.SerializeBufferFull =>
            SerializerException(SerializerErrorKind.PushError, error.message)
        case PostcardErrorKind.SerializeSeqLengthUnknown =>
            SerializerException(SerializerErrorKind.SeqLengthUnknown, error.message)
        case PostcardErrorKind.SerdeSerCustom | PostcardErrorKind.CollectStrError =>
            SerializerException(SerializerErrorKind.Custom, error.message)
        case _ => SerializerException(SerializerErrorKind.PushError, error.message)
    }
}

private func mapDeserializerError(error: PostcardException): DeserializerException {
    return match (error.kind) {
        case PostcardErrorKind.DeserializeUnexpectedEnd =>
            DeserializerException(DeserializerErrorKind.PopError, error.message)
        case PostcardErrorKind.DeserializeBadBool =>
            DeserializerException(DeserializerErrorKind.BadBool, error.message)
        case PostcardErrorKind.DeserializeBadVarint =>
            DeserializerException(DeserializerErrorKind.BadVarint, error.message)
        case PostcardErrorKind.DeserializeBadChar =>
            DeserializerException(DeserializerErrorKind.BadChar, error.message)
        case PostcardErrorKind.DeserializeBadUtf8 =>
            DeserializerException(DeserializerErrorKind.BadUtf8, error.message)
        case PostcardErrorKind.DeserializeBadOption =>
            DeserializerException(DeserializerErrorKind.BadOption, error.message)
        case PostcardErrorKind.WontImplement =>
            DeserializerException(DeserializerErrorKind.UnsupportedDeserAny, error.message)
        case _ => DeserializerException(DeserializerErrorKind.Custom, error.message)
    }
}

/** Cangjie postcard2 serializer façade over the core-backed data model. */
public class V2Serializer {
    private let inner: Serializer

    public init(flavor: SerializeFlavor) {
        inner = Serializer(flavor)
    }

    public func serializer(): Serializer {
        return inner
    }

    public func isHumanReadable(): Bool {
        return inner.isHumanReadable()
    }

    public func finalize(): Array<UInt8> {
        try {
            return inner.finalize()
        } catch (error: PostcardException) {
            throw SerializerException(SerializerErrorKind.FinalizeError, error.message)
        }
    }
}

/** Cangjie postcard2 deserializer façade over a core-backed Flavor. */
public class V2Deserializer {
    private let inner: Deserializer

    public init(flavor: DeserializeFlavor) {
        inner = Deserializer(flavor)
    }

    public func deserializer(): Deserializer {
        return inner
    }

    public func isHumanReadable(): Bool {
        return inner.isHumanReadable()
    }

    public func finalize(): Array<UInt8> {
        try {
            return inner.finalize()
        } catch (error: PostcardException) {
            throw DeserializerException(DeserializerErrorKind.FinalizeError, error.message)
        }
    }
}

public func serializeWithFlavorV2<T>(
    value: T,
    flavor: SerializeFlavor
): Array<UInt8> where T <: PostcardSerialize {
    let serializer = Serializer(flavor)
    try {
        value.serialize(serializer)
        return serializer.finalize()
    } catch (error: PostcardException) {
        throw mapSerializerError(error)
    }
}

public func toVecV2<T>(value: T): Array<UInt8> where T <: PostcardSerialize {
    return serializeWithFlavorV2<T>(value, ArraySerializeFlavor())
}

/** Returns the number of bytes written into the supplied fixed-capacity buffer. */
public func toSliceV2<T>(value: T, buffer: Array<UInt8>): Int64
    where T <: PostcardSerialize {
    let flavor = SliceSerializeFlavor(buffer)
    let serializer = Serializer(flavor)
    try {
        value.serialize(serializer)
        serializer.finalize()
        return serializer.position()
    } catch (error: PostcardException) {
        throw mapSerializerError(error)
    }
}

/** Stream serialized bytes directly into an existing generic byte sink. */
public func toExtendV2<T>(value: T, destination: ByteExtendSink): ByteExtendSink
    where T <: PostcardSerialize {
    let flavor = ExtendSerializeFlavor(destination)
    let serializer = Serializer(flavor)
    try {
        value.serialize(serializer)
        serializer.finalize()
        return flavor.sink()
    } catch (error: PostcardException) {
        throw mapSerializerError(error)
    }
}

public func serializedSizeV2<T>(value: T): Int64 where T <: PostcardSerialize {
    let serializer = Serializer(SizeSerializeFlavor())
    try {
        value.serialize(serializer)
        serializer.finalize()
        return serializer.position()
    } catch (error: PostcardException) {
        throw mapSerializerError(error)
    }
}

/** postcard2 from_bytes semantics: trailing bytes are ignored. */
public func fromBytesV2<T>(input: Array<UInt8>): T where T <: PostcardDeserialize<T> {
    let deserializer = Deserializer(SliceDeserializeFlavor(input))
    try {
        return T.deserialize(deserializer)
    } catch (error: PostcardException) {
        throw mapDeserializerError(error)
    }
}

public func takeFromBytesV2<T>(input: Array<UInt8>): (T, Array<UInt8>)
    where T <: PostcardDeserialize<T> {
    let deserializer = Deserializer(SliceDeserializeFlavor(input))
    try {
        let value = T.deserialize(deserializer)
        return (value, deserializer.finalize())
    } catch (error: PostcardException) {
        throw mapDeserializerError(error)
    }
}

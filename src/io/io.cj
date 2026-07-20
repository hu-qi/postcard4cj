package postcard4cj.io

import postcard4cj.core.*
import postcard4cj.serde_model.*
import postcard4cj.v2.DeserializerErrorKind
import postcard4cj.v2.DeserializerException
import postcard4cj.v2.SerializerErrorKind
import postcard4cj.v2.SerializerException
import postcard4cj.v2_eio.ByteReader
import postcard4cj.v2_eio.ByteWriter
import postcard4cj.v2_eio.fromEioV2
import postcard4cj.v2_eio.toEioV2

public class IoDeserializeResult<T> {
    public let value: T
    public let reader: ByteReader
    public let unusedScratch: Array<UInt8>

    public init(value: T, reader: ByteReader, unusedScratch: Array<UInt8>) {
        this.value = value
        this.reader = reader
        this.unusedScratch = unusedScratch
    }
}

private func mapLegacySerializer(error: SerializerException): PostcardException {
    return match (error.kind) {
        case SerializerErrorKind.SeqLengthUnknown =>
            PostcardException(PostcardErrorKind.SerializeSeqLengthUnknown, error.message)
        case SerializerErrorKind.Custom =>
            PostcardException(PostcardErrorKind.SerdeSerCustom, error.message)
        case _ => PostcardException(PostcardErrorKind.SerializeBufferFull, error.message)
    }
}

private func mapLegacyDeserializer(error: DeserializerException): PostcardException {
    return match (error.kind) {
        case DeserializerErrorKind.PopError =>
            PostcardException(PostcardErrorKind.DeserializeUnexpectedEnd, error.message)
        case DeserializerErrorKind.BadBool =>
            PostcardException(PostcardErrorKind.DeserializeBadBool, error.message)
        case DeserializerErrorKind.BadVarint =>
            PostcardException(PostcardErrorKind.DeserializeBadVarint, error.message)
        case DeserializerErrorKind.BadChar =>
            PostcardException(PostcardErrorKind.DeserializeBadChar, error.message)
        case DeserializerErrorKind.BadUtf8 =>
            PostcardException(PostcardErrorKind.DeserializeBadUtf8, error.message)
        case DeserializerErrorKind.BadOption =>
            PostcardException(PostcardErrorKind.DeserializeBadOption, error.message)
        case DeserializerErrorKind.UnsupportedDeserAny =>
            PostcardException(PostcardErrorKind.WontImplement, error.message)
        case _ => PostcardException(PostcardErrorKind.SerdeDeCustom, error.message)
    }
}

/** Legacy postcard to_io/to_eio language-level equivalent. */
public func toIo<T>(value: T, writer: ByteWriter): ByteWriter
    where T <: PostcardSerialize {
    try {
        return toEioV2<T>(value, writer)
    } catch (error: SerializerException) {
        throw mapLegacySerializer(error)
    }
}

/** Legacy postcard from_io/from_eio language-level equivalent. */
public func fromIo<T>(reader: ByteReader, scratch: Array<UInt8>): IoDeserializeResult<T>
    where T <: PostcardDeserialize<T> {
    try {
        let result = fromEioV2<T>(reader, scratch)
        return IoDeserializeResult<T>(
            result.value,
            result.reader,
            result.unusedScratch
        )
    } catch (error: DeserializerException) {
        throw mapLegacyDeserializer(error)
    }
}

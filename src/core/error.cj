package postcard4cj.core

/** Error categories aligned with the upstream postcard Error enum. */
public enum PostcardErrorKind {
    | WontImplement
    | NotYetImplemented
    | SerializeBufferFull
    | SerializeSeqLengthUnknown
    | DeserializeUnexpectedEnd
    | DeserializeBadVarint
    | DeserializeBadBool
    | DeserializeBadChar
    | DeserializeBadUtf8
    | DeserializeBadOption
    | DeserializeBadEnum
    | DeserializeBadEncoding
    | DeserializeBadCrc
    | SerdeSerCustom
    | SerdeDeCustom
    | CollectStrError
}

/** Exception carrying a stable Postcard error category. */
public class PostcardException <: Exception {
    public let kind: PostcardErrorKind

    public init(kind: PostcardErrorKind, message: String) {
        super(message)
        this.kind = kind
    }
}

public func postcardErrorMessage(kind: PostcardErrorKind): String {
    return match (kind) {
        case PostcardErrorKind.WontImplement =>
            "This is a feature that Postcard will never implement"
        case PostcardErrorKind.NotYetImplemented =>
            "This is a feature that Postcard intends to support, but does not yet"
        case PostcardErrorKind.SerializeBufferFull =>
            "The serialize buffer is full"
        case PostcardErrorKind.SerializeSeqLengthUnknown =>
            "The length of a sequence must be known"
        case PostcardErrorKind.DeserializeUnexpectedEnd =>
            "Hit the end of buffer, expected more data"
        case PostcardErrorKind.DeserializeBadVarint =>
            "Found an invalid or unterminated Postcard varint"
        case PostcardErrorKind.DeserializeBadBool =>
            "Found a bool that was not 0 or 1"
        case PostcardErrorKind.DeserializeBadChar =>
            "Found an invalid Unicode scalar value"
        case PostcardErrorKind.DeserializeBadUtf8 =>
            "Tried to parse invalid UTF-8"
        case PostcardErrorKind.DeserializeBadOption =>
            "Found an Option discriminant that was not 0 or 1"
        case PostcardErrorKind.DeserializeBadEnum =>
            "Found an enum discriminant outside the UInt32 range"
        case PostcardErrorKind.DeserializeBadEncoding =>
            "The original data was not well encoded"
        case PostcardErrorKind.DeserializeBadCrc =>
            "Bad CRC while deserializing"
        case PostcardErrorKind.SerdeSerCustom =>
            "Serialization error"
        case PostcardErrorKind.SerdeDeCustom =>
            "Deserialization error"
        case PostcardErrorKind.CollectStrError =>
            "Error while processing collect-string serialization"
    }
}

public func postcardException(kind: PostcardErrorKind): PostcardException {
    return PostcardException(kind, postcardErrorMessage(kind))
}

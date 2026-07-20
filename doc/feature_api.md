# postcard4cj Feature and API Guide

## 1. Package

```toml
[dependencies]
postcard4cj = "0.1.0"
```

The package is currently in release preparation. Until it is published to the Cangjie package repository, use the repository source according to the consuming project's dependency policy.

Supported compiler targets:

- Cangjie LTS 1.0.5
- Cangjie STS 1.1.3

## 2. Core codec interfaces

User-defined types participate in the codec through:

```cangjie
public interface PostcardEncode {
    func encode(encoder: PostcardEncoder): Unit
}

public interface PostcardDecode<T> {
    static func decode(decoder: PostcardDecoder): T
}
```

A manual implementation writes and reads fields in the same declaration order.

## 3. Basic serialization

### Encode to a growable byte array

```cangjie
let bytes = toBytes<MyType>(value)
```

### Decode an exact message

```cangjie
let value = fromBytes<MyType>(bytes)
```

Exact decoding rejects trailing bytes.

### Decode and return unused bytes

```cangjie
let result = takeFromByteArray<MyType>(bytes)
let value = result[0]
let remainder = result[1]
```

## 4. Primitive and compound values

The encoder/decoder support:

- Bool
- signed and unsigned 8/16/32/64/128-bit integers
- platform-width integer substitutions
- Float32 and Float64
- Rune
- Unit
- UTF-8 String
- byte arrays
- Option values
- sequences
- maps
- tuples
- structs
- unit, newtype, tuple and struct enum variants

Integer values use Postcard variable-length and ZigZag rules unless a fixed-width wrapper is selected.

## 5. Framing

### COBS

```cangjie
let frame = toBytesCobs<MyType>(value)
let decoded = fromBytesCobs<MyType>(frame)
let result = takeFromBytesCobs<MyType>(streamBytes)
```

`takeFromBytesCobs` decodes the first zero-delimited frame and returns all bytes after that frame as the remainder.

### CRC32C/iSCSI

```cangjie
let message = toBytesCrc32Iscsi<MyType>(value)
let decoded = fromBytesCrc32Iscsi<MyType>(message)
let result = takeFromBytesCrc32Iscsi<MyType>(streamBytes)
```

CRC helpers append and validate a CRC32C/iSCSI checksum. The take-style function returns bytes after the validated message.

## 6. Output and input Flavors

Serialization Flavors include:

- fixed caller-provided buffer
- growable Array
- Extend sink
- stream writer
- serialized-size counter
- COBS middleware
- CRC32C middleware

Deserialization Flavors include:

- byte slice source with remainder
- stream reader with scratch storage
- COBS-decoded source
- CRC32C-validated source

Use Flavor APIs when storage, framing, or streaming behavior must be composed explicitly. Use convenience functions for common byte-array workflows.

## 7. Fixed-width integers

`postcard4cj.fixint` provides little-endian and big-endian fixed-width codecs for 16/32/64/128-bit integer fields.

Fixed-width helpers are appropriate when the surrounding data model requires an exact byte width rather than Postcard's default variable-length representation.

## 8. IO

`postcard4cj.io` and `postcard4cj.v2_eio` use Cangjie-native `ByteReader` and `ByteWriter` abstractions.

```cangjie
postcard4cj.io.toIo<MyType>(writer, value)
let value = postcard4cj.io.fromIo<MyType>(reader, scratch)
```

Scratch storage is caller-provided where streaming decode requires temporary bytes.

## 9. Accumulator

`CobsAccumulator` accepts chunks from a byte stream and yields complete COBS frames without requiring the caller to align input chunks with frame boundaries.

The accumulator has a runtime capacity. Capacity overflow fails deterministically.

## 10. Schema

`postcard4cj.schema` provides:

- `NamedType`
- primitive, sequence, tuple, map, struct and enum schema nodes
- schema formatting
- recursive used-type discovery
- stable type/path keys
- Postcard serialization for schema values

Types implement:

```cangjie
public interface PostcardSchema<T> {
    static func schema(): NamedType
}
```

The NG namespace uses `PostcardSchemaNg<T>` and `schemaNg()`.

## 11. Dynamic values

`postcard4cj.dynamic` provides lossless schema-directed runtime values, including:

- primitive values
- sequences and tuples
- arbitrary-key maps
- structs and enum variants
- explicit `None` and `Some(Unit)` distinction
- schema values

JSON-compatible conversion is provided for data representable by the JSON model. Lossless Dynamic values should be used when JSON cannot preserve the original type distinction.

## 12. Macros

### Codec

```cangjie
@Postcard
public struct Message {
    public let id: UInt32
    public let name: String

    public init(id: UInt32, name: String) {
        this.id = id
        this.name = name
    }
}
```

### Schema

```cangjie
@PostcardSchema
public struct SchemaMessage {
    public let id: UInt32

    public init(id: UInt32) {
        this.id = id
    }
}
```

### Maximum serialized size

```cangjie
@PostcardMaxSize
public struct BoundedMessage {
    public let id: UInt32
    public let active: Bool

    public init(id: UInt32, active: Bool) {
        this.id = id
        this.active = active
    }
}
```

NG entry points are `@PostcardSchemaNg` and `@PostcardMaxSizeNg`.

Supported generic form:

```cangjie
@Postcard
public struct Pair<T, U> {
    public let first: T
    public let second: U

    public init(first: T, second: U) {
        this.first = first
        this.second = second
    }
}
```

The macros generate the required constraints for every generic parameter.

Current macro exclusions:

- generic enums
- declarations with an existing `where` clause
- rename attributes
- unbounded fields in MaxSize generation

Unsupported declarations produce compile-time diagnostics.

## 13. Maximum size and serialized size

- `serializedSize` calculates the encoded size of a concrete value.
- `PostcardMaxSize` describes the maximum unflavored Postcard size of a bounded type.
- MaxSize macros reject unbounded String and Array fields unless the user supplies an appropriate bounded wrapper or manual implementation.

## 14. Postcard2-style APIs

`postcard4cj.v2` provides a separate modern facade with:

- fixed and growable serialization
- Extend output
- serialized-size calculation
- exact and remainder-aware decode
- dedicated serializer/deserializer error categories

`postcard4cj.v2_eio` and `postcard4cj.v2_fixed` provide IO and runtime-capacity fixed-vector adapters.

## 15. Error handling

Codec failures are exposed as Cangjie exceptions with explicit error categories. Callers should catch the relevant exception type when malformed external input is expected.

Defined failure classes include:

- unexpected end of input
- trailing bytes
- invalid Bool or Option discriminant
- invalid UTF-8 or Rune
- invalid or non-canonical Varint
- unknown enum variant
- output capacity exhaustion
- malformed COBS
- CRC mismatch
- unsupported serialization/deserialization operation

## 16. Security guidance

- Treat all incoming lengths as untrusted.
- Prefer fixed-capacity or application-level limits for externally supplied collections.
- Use exact decode when a buffer must contain one and only one message.
- Use take-style decode only when processing an intentional message stream.
- Validate COBS and CRC framing before acting on decoded values.
- Do not suppress malformed-input exceptions without recording or handling the rejected input.

## 17. Compatibility references

- Detailed architecture: `doc/design.md`
- Upstream workspace mapping: `MIGRATION.md`
- Public API mapping: `API_COMPATIBILITY.md`
- Version history: `CHANGELOG.md`
- Upstream license record: `README.OpenSource`

# postcard4cj Feature and API Guide

[简体中文](feature_api.md) | English

## 1. Package and compiler support

```toml
[dependencies]
postcard4cj = "0.1.0"
```

The package is a release candidate. The source supports:

- Cangjie LTS 1.0.5
- Cangjie STS 1.1.3

The repository is bundle-ready. Installation from the center repository depends on completion of the external publishing operation.

## 2. Core interfaces

User-defined values participate in the codec through:

```cangjie
public interface PostcardEncode {
    func encode(encoder: PostcardEncoder): Unit
}

public interface PostcardDecode<T> {
    static func decode(decoder: PostcardDecoder): T
}
```

Manual implementations must write and read fields in the same order.

## 3. Basic serialization

```cangjie
let bytes = toBytes<MyType>(value)
let decoded = fromBytes<MyType>(bytes)
```

Exact decode rejects trailing input.

To process a stream and retain unused bytes:

```cangjie
let result = takeFromByteArray<MyType>(input)
let value = result[0]
let remainder = result[1]
```

## 4. Supported values

- Bool
- signed and unsigned 8/16/32/64/128-bit integers
- Float32 and Float64
- Rune and Unit
- UTF-8 String and byte arrays
- Option
- sequences and maps
- tuples and structs
- unit, newtype, tuple and struct enum variants

Postcard variable-length and ZigZag encoding is used unless a fixed-width wrapper is selected.

## 5. COBS framing

```cangjie
let frame = toBytesCobs<MyType>(value)
let value = fromBytesCobs<MyType>(frame)
let result = takeFromBytesCobs<MyType>(stream)
```

The take-style function decodes the first zero-delimited frame and returns all following bytes.

COBS output is built incrementally with a fixed maximum 254-byte pending segment.

## 6. Configurable CRC32 and CRC32C/iSCSI framing

```cangjie
let message = toBytesCrc32Iscsi<MyType>(value)
let value = fromBytesCrc32Iscsi<MyType>(message)
let result = takeFromBytesCrc32Iscsi<MyType>(stream)

let message2 = toBytesCrc32<MyType>(value, crc32IsoHdlcDigest())
```

Generic APIs accept a `Crc32Digest`; built-ins cover iSCSI (Castagnoli) and ISO-HDLC. Parameterless Flavors and `*Crc32Iscsi` helpers preserve the iSCSI default. Decoding validates the appended checksum and serialization updates it incrementally.

## 7. Flavors

Serialization Flavors support:

- fixed caller-provided buffers
- growable arrays
- Extend sinks
- stream writers
- serialized-size counters
- COBS middleware
- CRC32C middleware

Deserialization Flavors support:

- slices with remainder
- stream readers with scratch storage
- decoded COBS frames
- CRC32C-validated messages

Use convenience functions for common byte-array workflows and Flavors for explicit storage or framing composition.

`Flavor.snapshot()` remains non-mutating, and middleware finalization preserves declared composition order.

## 8. Fixed-width integers

`postcard4cj.fixint` provides little-endian and big-endian codecs for 16/32/64/128-bit integer fields.

Use fixed-width helpers only when the surrounding data format requires an exact width rather than default Postcard Varint encoding.

## 9. IO and accumulator

`postcard4cj.io` and `postcard4cj.v2_eio` use Cangjie-native `ByteReader` and `ByteWriter` interfaces.

`CobsAccumulator` accepts arbitrary stream chunks and yields complete COBS frames. Its runtime capacity is enforced deterministically.

## 10. Schema

`postcard4cj.schema` provides:

- primitive, sequence, tuple, map, struct and enum nodes
- schema formatting
- recursive used-type discovery
- stable type/path keys
- Postcard serialization of schema values

Types implement:

```cangjie
public interface PostcardSchema<T> {
    static func schema(): NamedType
}
```

The NG namespace uses `PostcardSchemaNg<T>` and `schemaNg()`.

## 11. Dynamic values

`postcard4cj.dynamic` provides lossless schema-directed runtime values for primitives, collections, structs, enum variants, arbitrary-key maps, Schema values, and explicit `None` versus `Some(Unit)`.

JSON-compatible conversion is available where JSON can preserve the represented data. Use the lossless Dynamic model when JSON would erase a type distinction.

## 12. Macros

### Codec struct

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

### Codec enum

```cangjie
@Postcard
public enum Command {
    | Ping
    | SetSpeed(UInt16)
    | Rename(String, Bool)
}
```

### Generic struct

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

### Generic enum

```cangjie
@Postcard
public enum ResultValue<T, U> {
    | Empty
    | Value(T)
    | Pair(T, U)
}
```

The macro generates the required codec, Schema, or MaxSize constraints for every type parameter.

### Existing `where` bounds

Generic declarations may already contain a `where` clause. The macros read existing upper bounds through the AST and merge them with generated Postcard constraints without redeclaring generic parameters.

### Schema and maximum size

Use the corresponding annotations:

```cangjie
@PostcardSchema
public struct SchemaMessage { /* fields and init */ }

@PostcardMaxSize
public struct BoundedMessage { /* bounded fields and init */ }
```

NG entry points are `@PostcardSchemaNg` and `@PostcardMaxSizeNg`.

All five codec/Schema/MaxSize entry points support non-generic and generic structs and exhaustive enums with one or more type parameters.

### Schema rename metadata

Named Schema macros provide Cangjie-native type, field, and enum-variant names:

```cangjie
@PostcardSchemaNamed["wire_record", "id=wire_id"]
public struct Record {
    public let id: UInt32
}
```

The NG equivalent is `@PostcardSchemaNgNamed[...]`. Rename metadata changes Schema names only and does not change wire bytes.

### Explicit exclusions

- non-exhaustive enum generation
- unbounded String/Array fields in MaxSize generation

Unsupported declarations produce compile-time diagnostics.

## 13. Size APIs

- `serializedSize` calculates the encoded size of a concrete value.
- `PostcardMaxSize` describes the maximum unflavored size of a bounded type.
- MaxSize macros reject unbounded fields unless the user supplies a bounded wrapper or manual implementation.

## 14. Postcard2-style API

`postcard4cj.v2` provides fixed, growable and Extend output, serialized-size calculation, exact decode, remainder decode, and dedicated error categories.

`postcard4cj.v2_eio` and `postcard4cj.v2_fixed` provide IO and runtime-capacity fixed-vector adapters.

## 15. Error handling

Failures are exposed as Cangjie exceptions with explicit categories, including:

- unexpected end or trailing bytes
- invalid Bool, Option, UTF-8, Rune or Varint
- unknown enum variant
- output capacity exhaustion
- malformed COBS
- CRC mismatch
- unsupported operations

Catch the relevant exception when decoding untrusted external data.

## 16. Security guidance

- Treat incoming lengths as untrusted.
- Apply application-level collection limits where needed.
- Use exact decode for one-message buffers.
- Use take-style decode only for intentional message streams.
- Validate framing before acting on decoded values.
- Do not suppress malformed-input failures silently.

Sequence and map decoding avoid direct large preallocation from malicious declared wire lengths.

## 17. Verification and references

The same source passes **197 tests** on both Cangjie 1.0.5 and 1.1.3.

The STS quality job also validates:

- HTML/XML/JSON coverage report generation
- 66.76% line coverage across all instrumented `src`
- 71.98% runtime-library coverage excluding tests, benchmarks, and compile-time macro packages
- 6/6 native benchmark cases
- `cjpm bundle --skip-lint`

Further documentation:

- `README.md`
- `doc/quickstart.zh-CN.md`
- `doc/feature_api.md`
- `doc/migration.zh-CN.md`
- `doc/design.en.md`
- `doc/cjcov/README.md`
- `MIGRATION.md`
- `API_COMPATIBILITY.md`
- `CHANGELOG.md`
- `README.OpenSource`

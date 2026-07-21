# postcard4cj Feature and API Guide

## 1. Package and compiler support

```toml
[dependencies]
postcard4cj = "0.1.0"
```

The package is in release preparation. The source supports:

- Cangjie LTS 1.0.5
- Cangjie STS 1.1.3

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

## 6. CRC32C/iSCSI framing

```cangjie
let message = toBytesCrc32Iscsi<MyType>(value)
let value = fromBytesCrc32Iscsi<MyType>(message)
let result = takeFromBytesCrc32Iscsi<MyType>(stream)
```

The decoder validates the appended checksum before returning a value.

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

The macro generates codec constraints for every type parameter.

### Schema and maximum size

Use the corresponding annotations:

```cangjie
@PostcardSchema
public struct SchemaMessage { /* fields and init */ }

@PostcardMaxSize
public struct BoundedMessage { /* bounded fields and init */ }
```

NG entry points are `@PostcardSchemaNg` and `@PostcardMaxSizeNg`.

All five macro entry points support non-generic and generic structs and exhaustive enums. Generic declarations may contain one or more parameters but must not already declare a `where` clause.

Current macro exclusions:

- merging an existing `where` clause with generated constraints
- rename and related attributes
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

## 17. Verification and references

The same source passes 178 tests on Cangjie 1.0.5 and 1.1.3.

Further documentation:

- `doc/design.md`
- `doc/cjcov/README.md`
- `MIGRATION.md`
- `API_COMPATIBILITY.md`
- `CHANGELOG.md`
- `README.OpenSource`

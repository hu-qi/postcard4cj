# postcard4cj

`postcard4cj` is a Cangjie-native implementation of the Postcard Wire Format 1.x,
targeting byte-for-byte interoperability with Rust `postcard = 1.1.3`.

> Status: prototype validated with Cangjie 1.1.3 on Linux x64. Both the Cangjie
> test suite and the Rust interoperability oracle pass in GitHub Actions.

## Implemented wire types

- `UInt8`, `UInt16`, `UInt32`, `UInt64`
- `Int8` as raw two's-complement byte
- `Int16`, `Int32`, `Int64` through ZigZag + unsigned Varint
- Rust-compatible `u128` and `i128` through Cangjie `BigInt`
- `PostcardUInt128` and `PostcardInt128` typed wrappers
- `Bool`
- `Float32`, `Float64` as fixed-width little-endian bit patterns
- length-prefixed byte arrays and UTF-8 strings
- `Rune`, `Unit`, `Option<T>`, sequences
- two-element tuples and ordered map-entry sequences
- enum variant indexes and payloads

## Typed API

Types can implement:

```cangjie
public interface PostcardEncode {
    func encode(encoder: PostcardEncoder): Unit
}

public interface PostcardDecode<T> {
    static func decode(decoder: PostcardDecoder): T
}
```

Top-level helpers include:

- `toBytes<T>(value)`
- `encodeTo<T>(value, buffer)`
- `fromBytes<T>(input)`
- `takeFromBytes<T>(input)`

`encodeTo` writes directly into a caller-provided `Array<UInt8>` and returns the
number of bytes written. Capacity exhaustion fails immediately.

## Attribute macro

The experimental `@Postcard` macro generates `PostcardEncode` and
`PostcardDecode<T>` implementations for non-generic structs and enums.

```cangjie
import postcard4cj.*
import postcard4cj.postcard_macro.*

@Postcard
public struct Record {
    public let id: UInt32
    public let delta: Int32
    public let note: Option<String>

    public init(id: UInt32, delta: Int32, note: Option<String>) {
        this.id = id
        this.delta = delta
        this.note = note
    }
}
```

Struct fields are encoded in declaration order. Enum indexes follow constructor
declaration order, matching Serde's default representation.

Current macro limitations:

- generic structs and enums are not supported
- non-exhaustive enums are rejected
- direct `BigInt` fields are ambiguous; use `PostcardUInt128` or `PostcardInt128`
- generated struct decoding expects a positional constructor matching field order
- private fields cannot be accessed from the generated extension

## Framing

Implemented framing helpers:

- zero-terminated COBS, including the canonical 254-byte boundary
- CRC-32/ISCSI (CRC32C), appended in little-endian order
- typed COBS and CRC32 encode/decode helpers

## Rust interoperability oracle

`interop/rust-oracle` uses the exact dependency:

```toml
postcard = "=1.1.3"
```

It verifies Golden Vectors for:

1. integers, Bool and String
2. floats, Option and Sequence
3. Rune, Unit, Tuple, ordered map entries and enum payloads
4. `u128::MAX`, `i128::MIN` and a negative i128 sample
5. COBS framing
6. CRC-32/ISCSI framing
7. generated struct and enum macro vectors

Run it with:

```bash
cd interop/rust-oracle
cargo test
cargo run
```

## Cangjie verification

GitHub Actions uses Cangjie 1.1.3 (`cjnative`) on Ubuntu 22.04. The SDK is
retrieved from the repository owner's OBS callback mirror and verified against
the SHA256 published on the Cangjie 1.1.3 download page.

```bash
cjpm build -V
cjpm test -V
```

Verified CI result:

- `cjpm build`: success
- core package tests: 27 passed
- macro package tests: 3 passed
- total: 30 passed, 0 failed, 0 skipped, 0 errors
- Rust Oracle: success
- CodeRabbit: success

## Wire-format notes

Postcard is not self-describing. Both sides must share the same schema, field
order, enum constructor order and integer signedness.

Maps are represented as a sequence of entries. For deterministic output, callers
must sort entries before encoding.

## Remaining work

- generic struct and enum macro support
- arbitrary tuple arity generation
- fixed-capacity COBS and CRC framing
- streaming IO and composable Flavor pipelines
- complete zero-extra-allocation path
- fuzzing and benchmarks

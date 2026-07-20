# Full repository migration matrix

Upstream baseline: `jamesmunns/postcard@de182557cff45f2ca9b2b67a6b93be5917612a44`.

This document defines what “complete migration” means. A byte-compatible encoder alone is not sufficient.

## Workspace mapping

| Upstream crate | Cangjie target | Required behavior | Current state |
|---|---|---|---|
| `postcard-core` | `postcard4cj.core` | framework-independent wire primitives, varints, discriminants, lengths, borrowed/temp reads | Substantial foundation: dedicated core package, complete primitive wire API, lengths/discriminants, stable errors and remainder; stream/temp-source substitution still pending |
| `postcard` | `postcard4cj`, `postcard4cj.serde_model`, `postcard4cj.flavors` | full serializer/deserializer data model, errors, helpers, flavors, IO, accumulator, fixint, size calculation | Partial: data model, composable buffer/COBS/CRC/size flavors, accumulator, fixint and size calculation implemented; stream IO and compatibility consolidation pending |
| `postcard-derive` | `postcard4cj.derive` | schema and max-size macro generation compatible with legacy APIs | Partial: basic struct/enum codec macro exists; schema and MaxSize generation pending |
| `postcard-derive-ng` | `postcard4cj.derive_ng` | next-generation derive behavior | Not implemented |
| `postcard-schema` | `postcard4cj.schema` | reflection-like type schema, stable type keys/hashes, owned schema, formatting, integrations | Not implemented |
| `postcard-schema-ng` | `postcard4cj.schema_ng` | next-generation schema model and derives | Not implemented |
| `postcard-dyn` | `postcard4cj.dynamic` | schema-directed dynamic encode/decode and JSON-compatible dynamic values | Not implemented |
| `postcard-dyn-ng` | `postcard4cj.dynamic_ng` | next-generation dynamic schema pipeline | Not implemented |
| `postcard2` | `postcard4cj.v2` | `postcard-core`-based serializer/deserializer and modern API surface | Not implemented as a separate compatibility layer |
| `postcard2-eio` | `postcard4cj.v2_eio` | stream reader/writer adapters corresponding to embedded IO | Not implemented |
| `postcard2-heapless` | `postcard4cj.v2_fixed` | fixed-capacity collection/storage adapters | Partial foundation: fixed-capacity Slice Flavor and buffer APIs implemented |

## Implemented and CI-validated foundation

The full-port branch currently contains the following Cangjie packages:

- `postcard4cj.core`
  - all Postcard primitive wire items
  - signed ZigZag and unsigned Varints through 128 bits
  - lengths, Option discriminants, enum discriminants and headerless aggregates
  - all 16 upstream Postcard error categories
  - fixed and growable core buffers
  - exact position/remainder handling and negative vectors
- `postcard4cj.flavors`
  - growable Array storage
  - fixed Slice storage
  - size-counting flavor
  - composable COBS and CRC32C serialization middleware
  - Slice, COBS and CRC32C deserialization sources
  - size hints and remainder semantics
- `postcard4cj.serde_model`
  - Cangjie-native `PostcardSerialize` / `PostcardDeserialize<T>`
  - complete primitive, Option, unit, newtype, tuple, struct, sequence, map and enum-variant model
  - known-length sequence/map enforcement
  - non-self-describing `deserializeAny` rejection
  - growable, fixed-buffer, flavored, exact and take-with-remainder helpers
  - serialized-size calculation via the counting flavor
- `postcard4cj.accumulator`
  - chunked zero-terminated COBS accumulation
  - `Consumed`, `OverFull`, `DeserError`, and typed `Success` results
  - multiple-frame remainder handling
- `postcard4cj.fixint`
  - fixed-width little- and big-endian codecs
  - Int/UInt 16, 32, 64 and 128-bit support
  - signed two's-complement and range validation
- `postcard4cj.max_size`
  - primitive maximum-size rules
  - user-type `PostcardMaxSize` interface
  - Option, Result, tuple, fixed array, bounded sequence/string/map and enum formulas
- existing compatibility layer
  - zero-terminated COBS and CRC32C helpers
  - fixed caller buffers and growable arrays
  - basic non-generic struct/enum `@Postcard` macro
  - Rust `postcard = 1.1.3` Golden Vector oracle

All packages above build and test under Cangjie 1.1.3 on Ubuntu 22.04.

## `postcard-core` data model coverage

The upstream core layer covers all Postcard wire items, not only primitive integers.

### Primitive items

- Bool
- Int8/16/32/64/128
- UInt8/16/32/64/128
- platform-width signed/unsigned integers
- Float32/64
- Unicode scalar value

### Tagged unions

- Option discriminant
- unit, newtype, tuple, and struct enum variants
- UInt32 variant discriminants

### Length-prefixed values

- UTF-8 strings
- byte arrays
- sequences
- maps
- owned and temporary/borrowed read paths where the Cangjie runtime permits them

### Headerless aggregates

- unit and unit structs
- newtype structs
- tuples and tuple structs
- structs

## `postcard` compatibility surface

### Error model

The dedicated Cangjie error type now contains all upstream categories:

- `WontImplement`
- `NotYetImplemented`
- `SerializeBufferFull`
- `SerializeSeqLengthUnknown`
- `DeserializeUnexpectedEnd`
- `DeserializeBadVarint`
- `DeserializeBadBool`
- `DeserializeBadChar`
- `DeserializeBadUtf8`
- `DeserializeBadOption`
- `DeserializeBadEnum`
- `DeserializeBadEncoding`
- `DeserializeBadCrc`
- serializer/deserializer custom errors
- collect-string error

### Serializer/deserializer data model

Implemented:

- primitive methods
- Option and unit forms
- unit/newtype/tuple/struct variants
- sequences and maps with known-length enforcement
- tuples, tuple structs and structs
- collect-string representation after Cangjie formatting
- human-readable flag fixed to false
- deserialize-any rejection consistent with Postcard’s non-self-describing format

### Serialization flavors

Implemented:

- fixed slice/buffer
- growable collection
- COBS middleware
- CRC32C middleware
- size-counting flavor
- composable finalization

Pending:

- generic collection Extend sink
- standard and embedded stream writers
- zero-extra-allocation incremental COBS/CRC middleware optimization

### Deserialization flavors

Implemented:

- slice source with remainder
- COBS decoding
- CRC32C validation
- size hints
- exact/take-one decoding with remainder

Pending:

- stream reader with temporary storage
- lifetime/borrowing substitutions documented per Cangjie runtime semantics

### Other modules

Implemented:

- incremental COBS accumulator
- fixed-width integer field codecs (`fixint`)
- serialized-size calculation
- maximum-size interface and primitive/composite formulas

Pending:

- MaxSize attribute-macro generation
- standard/embedded IO helpers

## Schema and dynamic values

Completion still requires the schema and dynamic crates, including:

- primitive, sequence, tuple, map, struct, and enum schema nodes
- stable schema/type keys and hashing
- owned schema representation and formatting
- macro-generated schema for user types
- dynamic values directed by a schema
- encode/decode between dynamic values and Postcard bytes
- JSON conversion where equivalent to upstream `serde_json` behavior

## `postcard2`

The port must also expose a second-generation layer separated from the core wire implementation:

- serializer/deserializer built on the core package
- current Cangjie interfaces and macro integrations
- stream adapter module
- fixed-capacity adapter module
- compatibility tests proving identical Postcard 1.x wire bytes

## Acceptance criteria

The port is complete only when all of the following are true:

1. Every upstream workspace crate has a documented Cangjie counterpart.
2. All public upstream behavior has an equivalent or an explicitly documented language-level substitution.
3. Primitive and composite Golden Vectors match Rust Postcard byte-for-byte.
4. Invalid bool, UTF-8, char, option, enum, varint, encoding, CRC, and truncated-input vectors return the matching error category.
5. Fixed-buffer, growable-buffer, stream, COBS, CRC32C, accumulator, and remainder APIs pass tests.
6. Struct/enum/schema/max-size macros compile and pass end-to-end tests.
7. Dynamic schema-driven round trips pass for JSON-compatible values.
8. The complete Cangjie workspace builds and tests under CI.
9. MIT and Apache-2.0 licenses and upstream attribution are present.
10. README no longer carries an “in progress” warning.

The repository remains an active port until all ten criteria are satisfied.

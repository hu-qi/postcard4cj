# Full repository migration matrix

Upstream baseline: `jamesmunns/postcard@de182557cff45f2ca9b2b67a6b93be5917612a44`.

This document defines what “complete migration” means. A byte-compatible encoder alone is not sufficient.

## Workspace mapping

| Upstream crate | Cangjie target | Required behavior | Current state |
|---|---|---|---|
| `postcard-core` | `postcard4cj.core` | framework-independent wire primitives, varints, discriminants, lengths, borrowed/temp reads | Partial: primitive codec exists; dedicated core package/API still required |
| `postcard` | `postcard4cj` | full serializer/deserializer data model, errors, helpers, flavors, IO, accumulator, fixint, size calculation | Partial: selected helpers and direct typed codec only |
| `postcard-derive` | `postcard4cj.derive` | schema and max-size macro generation compatible with legacy APIs | Not implemented |
| `postcard-derive-ng` | `postcard4cj.derive_ng` | next-generation derive behavior | Not implemented |
| `postcard-schema` | `postcard4cj.schema` | reflection-like type schema, stable type keys/hashes, owned schema, formatting, integrations | Not implemented |
| `postcard-schema-ng` | `postcard4cj.schema_ng` | next-generation schema model and derives | Not implemented |
| `postcard-dyn` | `postcard4cj.dynamic` | schema-directed dynamic encode/decode and JSON-compatible dynamic values | Not implemented |
| `postcard-dyn-ng` | `postcard4cj.dynamic_ng` | next-generation dynamic schema pipeline | Not implemented |
| `postcard2` | `postcard4cj.v2` | `postcard-core`-based serializer/deserializer and modern API surface | Not implemented |
| `postcard2-eio` | `postcard4cj.v2_eio` | stream reader/writer adapters corresponding to embedded IO | Not implemented |
| `postcard2-heapless` | `postcard4cj.v2_fixed` | fixed-capacity collection/storage adapters | Partial concept only: fixed output buffer exists |

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

Implement the upstream error categories as a dedicated Cangjie error type:

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

Provide a Cangjie-native equivalent of the complete Serde-facing model:

- primitive methods
- Option and unit forms
- unit/newtype/tuple/struct variants
- sequences and maps with known-length enforcement
- tuples, tuple structs, structs
- collect-string formatting
- human-readable flag fixed to false
- deserialize-any rejection consistent with Postcard’s non-self-describing format

### Serialization flavors

- fixed slice/buffer
- growable collection
- generic extend sink
- stream writer
- COBS middleware
- CRC32C middleware
- size-counting flavor
- composable finalization

### Deserialization flavors

- slice source with remainder
- stream reader with temporary storage
- COBS decoding
- CRC32C validation
- size hints
- exact/take-one decoding with remainder

### Other modules

- incremental COBS accumulator
- fixed-width integer wrappers (`fixint`)
- serialized-size calculation
- maximum-size interface and derive support
- standard/embedded IO helpers

## Schema and dynamic values

Completion requires the schema and dynamic crates, including:

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

## Current Phase 1 foundation

The retained prototype currently provides:

- core integer encodings including `BigInt`-backed Rust-compatible 128-bit integers
- Bool, floats, bytes, UTF-8 strings, Rune, Option, Unit
- sequences, tuple-2, ordered map entries, enum indices
- fixed and growable output buffers
- COBS and CRC32C helpers
- a basic non-generic struct/enum `@Postcard` macro
- Rust 1.1.3 Golden Vector oracle

These capabilities are useful and tested, but represent only the initial compatibility layer.

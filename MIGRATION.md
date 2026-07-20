# Full repository migration matrix

Upstream behavior baseline: `jamesmunns/postcard@de182557cff45f2ca9b2b67a6b93be5917612a44`.

This document defines what complete migration means for postcard4cj. The implementation, tests, and CI are pure Cangjie; the upstream repository is a protocol and behavior reference only.

## Pure Cangjie invariant

The release branch must contain:

- no `.rs` source files
- no `Cargo.toml` or `Cargo.lock`
- no Rust toolchain configuration
- no Rust build/test workflow
- no foreign-language implementation used by the runtime library

CI enforces this invariant before compiling the Cangjie workspace.

## Workspace mapping

| Upstream crate | Cangjie target | Current state |
|---|---|---|
| `postcard-core` | `postcard4cj.core` | Implemented: framework-independent primitives, varints, discriminants, lengths, owned/temp-read substitutions, errors, positions and remainder |
| `postcard` | `postcard4cj`, `postcard4cj.serde_model`, `postcard4cj.flavors`, `postcard4cj.accumulator`, `postcard4cj.fixint`, `postcard4cj.io`, `postcard4cj.max_size` | Implemented: data model, helpers, fixed/growable/Extend/stream flavors, COBS, CRC32C, accumulator, fixint, size and IO |
| `postcard-derive` | `postcard4cj.postcard_macro` | Implemented for non-generic structs/enums; generic bounds and rename attributes remain under audit |
| `postcard-derive-ng` | `postcard4cj.derive_ng` | Implemented for the same bounded declaration set as the legacy macro namespace |
| `postcard-schema` | `postcard4cj.schema` | Implemented: schema graph, wire codec, formatting, recursive discovery and stable keys |
| `postcard-schema-ng` | `postcard4cj.schema_ng` | Implemented with an independent NG interface over the validated runtime-owned graph |
| `postcard-dyn` | `postcard4cj.dynamic` | Implemented: lossless schema-directed values and JSON-compatible conversion |
| `postcard-dyn-ng` | `postcard4cj.dynamic_ng` | Implemented: NG dynamic encode/decode, JSON and remainder APIs |
| `postcard2` | `postcard4cj.v2` | Implemented: modern facade, error model, fixed/growable/Extend APIs and remainder semantics |
| `postcard2-eio` | `postcard4cj.v2_eio` | Implemented through Cangjie `ByteReader` and `ByteWriter` |
| `postcard2-heapless` | `postcard4cj.v2_fixed` | Implemented through runtime-capacity `FixedByteVec` and `FixedVecFlavor` |

## Implemented data model

### Primitive items

- Bool
- Int8/16/32/64/128
- UInt8/16/32/64/128
- platform-width signed and unsigned integers using the 64-bit Cangjie runtime representation
- Float32/64
- Unicode scalar values

### Tagged unions

- Option discriminants
- unit, newtype, tuple and struct enum variants
- UInt32 variant discriminants

### Length-prefixed values

- UTF-8 strings
- byte arrays
- sequences
- maps
- owned and scratch-buffer read paths appropriate to Cangjie ownership semantics
- capped initial allocations for untrusted sequence and map lengths

### Headerless aggregates

- unit and unit structs
- newtype structs
- tuples and tuple structs
- named structs

## Serializer and deserializer surface

Implemented:

- Cangjie-native `PostcardSerialize` / `PostcardDeserialize<T>`
- primitive methods
- Option and unit forms
- unit/newtype/tuple/struct variants
- sequences and maps with known-length enforcement
- collect-string representation
- non-self-describing `deserializeAny` rejection
- exact decoding and take-with-remainder decoding
- all 16 Postcard 1.x error categories

## Flavors and storage

Implemented serialization flavors:

- fixed slice/buffer
- growable Array
- generic `ByteExtendSink`
- stream writer
- size counter
- COBS middleware
- CRC32C middleware
- composable finalization

Implemented deserialization flavors:

- slice source with remainder
- stream reader with caller scratch storage
- COBS decoding
- CRC32C validation
- size hints

Optimization still planned:

- incremental COBS/CRC operation with lower temporary allocation

## Other modules

Implemented:

- incremental COBS accumulator
- fixed-width LE/BE integer field codecs
- serialized-size calculation
- primitive and composite maximum-size formulas
- `@PostcardMaxSize` / `@PostcardMaxSizeNg`
- legacy and modern stream IO helpers
- fixed-capacity byte-vector adapter

## Schema and dynamic values

Implemented:

- primitive, sequence, tuple, map, struct and enum schema nodes
- stable type/path keys using FNV-1a markers compatible with the upstream algorithm
- runtime-owned recursive schema graph
- schema formatting and recursive used-type discovery
- macro-generated schemas for supported declarations
- schema-directed lossless dynamic values
- Postcard encode/decode for dynamic values
- JSON-compatible conversion
- distinct `None` and `Some(Unit)` representation
- arbitrary-key maps in the lossless model

## Language-level substitutions

The following are deliberate Cangjie implementations rather than one-to-one language constructs:

- owned `String` and `Array<UInt8>` replace lifetime-bound borrowed strings and byte slices
- caller scratch arrays replace lifetime-based temporary borrowing
- runtime-capacity `FixedByteVec` replaces const-generic fixed vectors
- exceptions replace Rust-style generic `Result` return types
- `ByteReader` / `ByteWriter` replace versioned embedded-IO traits
- one runtime-owned schema graph replaces separate static-reference and owned trees

These substitutions must preserve the wire format and observable behavior at the public API boundary.

## Pure Cangjie compatibility verification

Compatibility is checked entirely in Cangjie using fixed Golden Vectors and negative tests. The suite covers:

- records and generated codecs
- primitive and composite values
- COBS framing and frame remainder
- CRC32C framing and remainder
- 128-bit boundaries
- enum declaration order
- malformed Bool, Option, UTF-8, Rune, Varint, COBS and CRC inputs
- truncated input
- malicious sequence/map lengths without untrusted preallocation

## Remaining work before a release-ready claim

1. Complete the line-by-line public API and convenience-alias audit.
2. Add generic struct/enum macro support where the Cangjie AST and type system permit it.
3. Add rename and related macro attributes, or document explicit unsupported cases.
4. Expand malformed-input and edge-case parity tests.
5. Provide Cangjie-native adapters or explicit exclusions for optional ecosystem integrations.
6. Benchmark memory, CPU and output size.
7. Optimize buffered COBS/CRC middleware.
8. Finalize package and release documentation.

## Acceptance criteria

The implementation is release-ready only when:

1. Every upstream workspace crate has a documented Cangjie counterpart.
2. Every public behavior has an equivalent or documented Cangjie substitution.
3. Primitive and composite Golden Vectors pass in pure Cangjie tests.
4. Invalid-input vectors return the intended error category.
5. Fixed, growable, Extend, stream, COBS, CRC32C, accumulator and remainder APIs pass.
6. Codec, schema and max-size macros pass end-to-end tests for the declared support boundary.
7. Dynamic schema-driven and JSON-compatible round trips pass.
8. The complete Cangjie workspace builds and tests under CI.
9. CI proves that no Rust source/toolchain files are present.
10. License and upstream attribution files are present.

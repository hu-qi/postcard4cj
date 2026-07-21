# Full repository migration matrix

Upstream behavior baseline: `jamesmunns/postcard@de182557cff45f2ca9b2b67a6b93be5917612a44`.

postcard4cj is an independent pure Cangjie implementation. The upstream repository is a protocol and behavior reference only.

## Pure Cangjie invariant

The repository and every release branch must contain:

- no `.rs` source files
- no `Cargo.toml` or `Cargo.lock`
- no Rust toolchain configuration
- no Rust build/test workflow
- no foreign-language implementation used by the runtime library

CI checks this invariant before compiling.

## Supported compiler lines

| Release line | Compiler | Status |
|---|---|---|
| LTS | Cangjie 1.0.5 | Build and 178 tests passed |
| STS | Cangjie 1.1.3 | Build and 178 tests passed |

The same source tree currently works on both versions. Version-specific release branches are retained for package publication and maintenance, not because the source has diverged.

## Workspace mapping

| Upstream crate | Cangjie target | State |
|---|---|---|
| `postcard-core` | `postcard4cj.core` | Implemented |
| `postcard` | `postcard4cj` plus flavors, IO, accumulator, fixint and MaxSize packages | Implemented |
| `postcard-derive` | `postcard4cj.postcard_macro` | Codec, Schema and MaxSize generation implemented within the declared boundary |
| `postcard-derive-ng` | `postcard4cj.derive_ng` | NG Schema and MaxSize generation implemented within the declared boundary |
| `postcard-schema` | `postcard4cj.schema` | Implemented |
| `postcard-schema-ng` | `postcard4cj.schema_ng` | Implemented |
| `postcard-dyn` | `postcard4cj.dynamic` | Implemented |
| `postcard-dyn-ng` | `postcard4cj.dynamic_ng` | Implemented |
| `postcard2` | `postcard4cj.v2` | Implemented |
| `postcard2-eio` | `postcard4cj.v2_eio` | Implemented with Cangjie IO |
| `postcard2-heapless` | `postcard4cj.v2_fixed` | Implemented with runtime capacity |

## Implemented wire model

- Bool
- signed and unsigned 8/16/32/64/128-bit integers
- platform-width integer substitutions
- Float32 and Float64
- Rune
- Unit
- UTF-8 strings and byte arrays
- Option
- sequences and maps
- tuples and named structs
- unit, newtype, tuple and struct enum variants
- exact decoding and take-with-remainder decoding

Postcard Varint, ZigZag, length and declaration-order rules are preserved.

## Flavors and storage

Implemented serialization targets:

- caller-provided fixed buffers
- growable arrays
- Extend sinks
- stream writers
- size counters
- COBS framing
- CRC32C/iSCSI framing

Implemented deserialization sources:

- slices with remainder
- stream readers with scratch storage
- COBS frames
- CRC32C-validated messages

Runtime-capacity fixed vectors replace const-generic storage. COBS and CRC middleware may currently buffer temporary bytes; incremental lower-allocation processing is a later optimization.

## Other modules

Implemented:

- incremental COBS accumulator
- fixed-width LE/BE 16/32/64/128-bit codecs
- serialized-size calculation
- maximum-size formulas
- legacy and modern IO helpers
- postcard2-style API, IO and fixed-capacity adapters

## Schema and dynamic values

Implemented:

- primitive, sequence, tuple, map, struct and enum Schema nodes
- runtime-owned recursive Schema graph
- formatting and recursive used-type discovery
- upstream-compatible FNV type/path keys
- Schema serialization through Postcard
- lossless schema-directed Dynamic values
- arbitrary-key maps
- explicit `None` versus `Some(Unit)`
- JSON-compatible conversion
- legacy and NG namespaces

## Macro coverage

| Macro | Struct | Enum | Generic struct | Generic enum |
|---|---:|---:|---:|---:|
| `@Postcard` | Yes | Yes | Yes | Yes |
| `@PostcardSchema` | Yes | Yes | Yes | Yes |
| `@PostcardMaxSize` | Yes | Yes | Yes | Yes |
| `@PostcardSchemaNg` | Yes | Yes | Yes | Yes |
| `@PostcardMaxSizeNg` | Yes | Yes | Yes | Yes |

Generic support accepts one or more type parameters when the declaration has no existing `where` clause. Generated extensions add the required codec, Schema, or MaxSize constraint for every type parameter.

Still pending:

- safely merging pre-existing generic constraints
- rename and related macro attributes

Non-exhaustive enums are rejected because their stable variant set cannot be derived. Unbounded String and Array fields are rejected by MaxSize generation.

## Language-level substitutions

- Cangjie-owned String and byte arrays replace lifetime-bound borrowed data.
- Caller scratch arrays replace temporary borrowed storage.
- Runtime-capacity vectors replace const-generic vectors.
- Exceptions replace Rust `Result` surfaces while preserving error categories.
- Cangjie `ByteReader` and `ByteWriter` replace embedded-IO traits.
- One runtime-owned Schema graph replaces separate static and owned trees.

## Compatibility verification

Pure Cangjie tests cover:

- primitive and compound Golden Vectors
- signed and unsigned 128-bit boundaries
- enum declaration order
- COBS and CRC32C framing and remainder behavior
- invalid Bool, Option, UTF-8, Rune, Varint, COBS and CRC input
- truncated data
- malicious sequence/map lengths without direct wire-count allocation
- fixed, growable, Extend and stream paths
- legacy and NG generated structs and enums
- single- and multi-parameter generic structs and enums

Latest result on both Cangjie 1.0.5 and 1.1.3: **178 passed, 0 failed, 0 skipped, 0 errors**.

## Remaining work before release-ready status

1. Finish the line-by-line public API and alias audit.
2. Merge existing generic `where` constraints safely.
3. Implement rename and related macro attributes.
4. Expand malformed-input and edge-case parity tests.
5. Provide Cangjie-native optional ecosystem adapters or explicit exclusions.
6. Generate and retain a numerical `cjcov` report.
7. Benchmark memory, CPU and output size.
8. Optimize buffered COBS/CRC middleware.
9. Complete center-repository publication and release artifacts.

## Acceptance criteria

1. Every upstream workspace crate has a documented Cangjie counterpart.
2. Every public behavior has an equivalent or documented substitution.
3. Golden Vectors pass in pure Cangjie tests.
4. Invalid inputs return the intended error category.
5. Fixed, growable, Extend, stream, COBS, CRC32C, accumulator and remainder APIs pass.
6. Codec, Schema and MaxSize macros pass for the declared generic boundary.
7. Dynamic and JSON-compatible round trips pass.
8. LTS and STS build and test successfully.
9. CI proves no Rust source/toolchain artifacts are present.
10. Required design, API, coverage, changelog and open-source documents are present.

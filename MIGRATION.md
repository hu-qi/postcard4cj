# Full repository migration matrix

Upstream behavior baseline: `jamesmunns/postcard@de182557cff45f2ca9b2b67a6b93be5917612a44`.

postcard4cj is an independent pure Cangjie implementation. The upstream repository is a protocol and behavior reference only.

Chinese migration guidance: [`doc/migration.zh-CN.md`](doc/migration.zh-CN.md).

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
| LTS | Cangjie 1.0.5 | Build and 189 tests passed |
| STS | Cangjie 1.1.3 | Build and 189 tests passed |

The same source tree works on both versions. Version-specific release branches are retained for package publication and maintenance, not because the source has diverged.

## Workspace mapping

| Upstream crate | Cangjie target | State |
|---|---|---|
| `postcard-core` | `postcard4cj.core` | Implemented |
| `postcard` | `postcard4cj` plus flavors, IO, accumulator, fixint and MaxSize packages | Implemented |
| `postcard-derive` | `postcard4cj.postcard_macro` | Codec, Schema and MaxSize generation implemented |
| `postcard-derive-ng` | `postcard4cj.derive_ng` | NG Schema and MaxSize generation implemented |
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

Runtime-capacity fixed vectors replace const-generic storage.

COBS output is built incrementally with at most a 254-byte pending segment. CRC32C is updated while bytes flow through the Flavor, avoiding a second complete-message copy during finalization. `snapshot()` remains non-mutating and nested middleware order is preserved.

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

| Macro | Struct | Enum | Generic struct | Generic enum | Existing `where` merge |
|---|---:|---:|---:|---:|---:|
| `@Postcard` | Yes | Yes | Yes | Yes | Yes |
| `@PostcardSchema` | Yes | Yes | Yes | Yes | Yes |
| `@PostcardMaxSize` | Yes | Yes | Yes | Yes | Yes |
| `@PostcardSchemaNg` | Yes | Yes | Yes | Yes | Yes |
| `@PostcardMaxSizeNg` | Yes | Yes | Yes | Yes | Yes |

Generic support accepts one or more type parameters. Existing upper bounds are read through the AST and merged with generated codec, Schema, or MaxSize constraints without redeclaring generic parameters.

Named Schema entry points are also implemented:

- `@PostcardSchemaNamed[...]`
- `@PostcardSchemaNgNamed[...]`

They support Cangjie-native type, field, and enum-variant names without changing wire bytes.

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
- truncated and trailing data
- malicious sequence/map lengths without direct wire-count allocation
- fixed, growable, Extend and stream paths
- legacy and NG generated structs and enums
- single- and multi-parameter generic structs and enums
- existing `where` bound merging
- Schema type, field, and enum-variant rename metadata

Latest result on both Cangjie 1.0.5 and 1.1.3: **189 passed, 0 failed, 0 skipped, 0 errors**.

The STS quality job additionally validates:

- `cjcov` HTML/XML/JSON generation
- 66.30% line coverage across all instrumented `src`
- 71.75% runtime-library coverage excluding tests, benchmarks, and compile-time macro packages
- 6/6 native benchmark cases
- `cjpm bundle --skip-lint`
- `postcard4cj-0.1.0.cjp` artifact generation

## Release-candidate status

The repository implementation and package bundle are release-candidate complete. Remaining operations require external credentials or ecosystem decisions rather than additional hidden runtime implementation:

1. publish to the Cangjie center repository with a maintainer token;
2. mirror to AtomGit with valid external credentials;
3. add Cangjie-native adapters for optional ecosystem types when demanded, or keep their exclusions explicit;
4. continue reducing non-blocking `cjlint` warning debt.

## Acceptance criteria

1. Every upstream workspace crate has a documented Cangjie counterpart.
2. Every public behavior has an equivalent or documented substitution.
3. Golden Vectors pass in pure Cangjie tests.
4. Invalid inputs return the intended error category.
5. Fixed, growable, Extend, stream, COBS, CRC32C, accumulator and remainder APIs pass.
6. Codec, Schema and MaxSize macros pass for structs, exhaustive enums, generics, and existing-bound merging.
7. Dynamic and JSON-compatible round trips pass.
8. LTS and STS build and test successfully.
9. CI proves no Rust source/toolchain artifacts are present.
10. Design, API, Chinese usage, coverage, benchmark, changelog and open-source documents are present.

# Public API compatibility audit

Behavior baseline: `jamesmunns/postcard@de182557cff45f2ca9b2b67a6b93be5917612a44`.

postcard4cj is implemented entirely in Cangjie. The upstream project defines protocol behavior and API concepts only; it is not compiled, executed, or distributed by this repository.

Chinese migration guidance: [`doc/migration.zh-CN.md`](doc/migration.zh-CN.md).

## Compatibility status

| Upstream workspace crate | Cangjie package | Status |
|---|---|---|
| `postcard-core` | `postcard4cj.core` | Implemented |
| `postcard` | `postcard4cj` and utility packages | Implemented |
| `postcard-derive` | `postcard4cj.postcard_macro` | Implemented |
| `postcard-derive-ng` | `postcard4cj.derive_ng` | Implemented |
| `postcard-schema` | `postcard4cj.schema` | Implemented |
| `postcard-schema-ng` | `postcard4cj.schema_ng` | Implemented |
| `postcard-dyn` | `postcard4cj.dynamic` | Implemented |
| `postcard-dyn-ng` | `postcard4cj.dynamic_ng` | Implemented |
| `postcard2` | `postcard4cj.v2` | Implemented |
| `postcard2-eio` | `postcard4cj.v2_eio` | Implemented through Cangjie IO interfaces |
| `postcard2-heapless` | `postcard4cj.v2_fixed` | Implemented with runtime capacity |

## Core wire APIs

| Upstream concept | Cangjie mapping | Status |
|---|---|---|
| serialization Flavor | `SerializeFlavor` | Implemented |
| deserialization Flavor | `DeserializeFlavor` | Implemented |
| primitive signed/unsigned integers | encoder/decoder methods through 128-bit | Implemented |
| platform-width integers | 64-bit Cangjie runtime substitution | Implemented |
| Bool, floats, char/Rune | corresponding encoder/decoder methods | Implemented |
| String and bytes | owned Cangjie values | Implemented |
| Option and discriminants | Option/enum helpers | Implemented |
| sequence and map lengths | length-prefixed helpers with untrusted-length allocation protection | Implemented |
| exact decode | `fromBytes` / `fromByteArray` | Implemented |
| take with remainder | `takeFromByteArray` and related helpers | Implemented |

## Top-level serialization

| Upstream API family | Cangjie mapping | Status |
|---|---|---|
| `to_slice` | `toSlice` / `encodeTo` | Implemented |
| owned vector output | `toBytes` / `toByteArray` / `toVecV2` | Implemented |
| Extend output | `ExtendSerializeFlavor` / `toExtendV2` | Implemented |
| IO/EIO output | `postcard4cj.io.toIo` / `toEioV2` | Implemented |
| COBS output | `toBytesCobs`, `encodeToCobs`, COBS Flavor | Implemented incrementally |
| CRC32C output | `toBytesCrc32Iscsi`, `encodeToCrc32Iscsi`, CRC Flavor | Implemented incrementally |
| serialized-size calculation | `serializedSize` / `serializedSizeV2` | Implemented |

## Top-level deserialization

| Upstream API family | Cangjie mapping | Status |
|---|---|---|
| exact bytes decode | `fromBytes`, `fromByteArray`, `fromBytesV2` | Implemented |
| bytes decode with remainder | `takeFromByteArray`, `takeFromBytesV2` | Implemented |
| COBS exact decode | `fromBytesCobs` | Implemented |
| COBS remainder decode | `takeFromBytesCobs` | Implemented |
| CRC32C exact decode | `fromBytesCrc32Iscsi` | Implemented |
| CRC32C remainder decode | `takeFromBytesCrc32Iscsi` | Implemented |
| IO/EIO input | `postcard4cj.io.fromIo` / `fromEioV2` | Implemented |

## Flavors and storage

| Upstream Flavor/concept | Cangjie mapping | Status |
|---|---|---|
| fixed slice | `SliceSerializeFlavor` | Implemented |
| fixed bounded vector | `FixedVecFlavor` / `FixedByteVec` | Runtime-capacity substitution |
| growable vector | `ArraySerializeFlavor` | Implemented |
| Extend sink | `ExtendSerializeFlavor` | Implemented |
| stream writer/reader | Cangjie `ByteWriter` / `ByteReader` | Implemented |
| size counter | `SizeSerializeFlavor` | Implemented |
| COBS modifier/source | COBS serialize/deserialize Flavors | Implemented |
| CRC modifier/source | CRC32C serialize/deserialize Flavors | Implemented |

COBS construction keeps at most a 254-byte pending segment. CRC32C is updated as bytes are written. Finalization does not require a second complete-message copy, `snapshot()` remains non-mutating, and nested Flavor order is preserved.

## Additional modules

| Upstream module | Cangjie mapping | Status |
|---|---|---|
| COBS accumulator | `CobsAccumulator` | Implemented |
| fixed-width integers | `postcard4cj.fixint` | Implemented for LE/BE 16/32/64/128-bit values |
| maximum serialized size | `PostcardMaxSize` | Implemented |
| Schema graph and formatting | `postcard4cj.schema` | Implemented |
| stable Schema keys | `keyForPath`, `keyForSchemaPath` | Implemented with upstream-compatible FNV markers |
| dynamic lossless values | `postcard4cj.dynamic` | Implemented |
| JSON-compatible conversion | dynamic JSON helpers | Implemented |
| Postcard2-style facade | `postcard4cj.v2` | Implemented |

## Macro compatibility

| Capability | Cangjie entry point | Status |
|---|---|---|
| codec generation | `@Postcard` | Structs and exhaustive enums implemented |
| legacy Schema generation | `@PostcardSchema` | Structs and exhaustive enums implemented |
| legacy MaxSize generation | `@PostcardMaxSize` | Bounded structs and exhaustive enums implemented |
| NG Schema generation | `@PostcardSchemaNg` | Structs and exhaustive enums implemented |
| NG MaxSize generation | `@PostcardMaxSizeNg` | Bounded structs and exhaustive enums implemented |
| one or more generic type parameters | all five entry points | Implemented |
| merge existing generic constraints | all five entry points | Implemented through AST bound merging |
| named Schema metadata | `@PostcardSchemaNamed[...]`, `@PostcardSchemaNgNamed[...]` | Type, field, and variant names implemented |
| declaration-order field/variant semantics | all relevant macros | Implemented |
| non-exhaustive enum generation | enum macros | Explicitly rejected |
| unbounded String/Array MaxSize | MaxSize macros | Explicitly rejected |

Generated parameter lists and bounds are rebuilt from identifier tokens. Existing `where` upper bounds are preserved and merged without redeclaring type parameters.

Named Schema metadata changes Schema names only and does not change wire bytes.

## Language-level substitutions

- Owned `String` and `Array<UInt8>` replace lifetime-bound borrowed values.
- Caller scratch arrays replace temporary lifetime borrowing.
- Runtime-capacity fixed vectors replace const-generic storage.
- Cangjie exceptions replace Rust `Result` return surfaces while retaining explicit error categories.
- `ByteReader` and `ByteWriter` replace versioned embedded-IO traits.
- One runtime-owned Schema graph replaces separate static-reference and owned trees.

These substitutions preserve wire bytes and observable error/capacity behavior where an upstream equivalent exists.

## Optional ecosystem integrations

The following upstream integrations require Cangjie-native types or explicit exclusions:

- UUID
- date/time types
- matrix/vector types
- fixed-point types
- diagnostic formatting integrations
- large fixed-array helpers
- historical bounded-vector and embedded-IO aliases

No integration is implemented by embedding Rust code. See `doc/optional_integrations.md` for the recorded decisions.

## Verification

The pure Cangjie CI matrix validates the same source tree on:

- Cangjie LTS 1.0.5
- Cangjie STS 1.1.3

Latest result on both release lines:

- pure-source gate: passed
- build: passed
- tests: **189 passed, 0 failed, 0 skipped, 0 errors**

The STS quality job also validates:

- `cjcov` HTML/XML/JSON report generation
- 66.28% line coverage across all instrumented `src`
- 71.75% runtime-library coverage excluding tests, benchmarks, and compile-time macro packages
- 6/6 native benchmark cases
- `cjpm bundle --skip-lint`
- `postcard4cj-0.1.0.cjp` artifact generation

See `README.md`, `README.en.md`, `doc/quickstart.zh-CN.md`, `doc/feature_api.md`, `doc/feature_api.en.md`, `doc/design.md`, `doc/design.en.md`, and `MIGRATION.md` for usage, architecture, and detailed substitutions.

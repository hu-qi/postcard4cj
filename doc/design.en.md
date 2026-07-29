# postcard4cj Design

[简体中文](design.md) | English

## 1. Purpose

postcard4cj is a pure Cangjie implementation of the Postcard binary wire format and the observable behavior of the upstream Postcard workspace.

Design goals:

1. Preserve Postcard wire compatibility.
2. Expose Cangjie-native APIs rather than wrapping or executing Rust code.
3. Support Cangjie LTS 1.0.5 and STS 1.1.3 from one source tree.
4. Cover fixed-buffer, growable, streaming, COBS, CRC32C, Schema, Dynamic and macro use cases.
5. Reject malformed or adversarial input deterministically without untrusted eager allocation.
6. Document every deliberate language-level substitution.

Upstream behavior baseline:

```text
jamesmunns/postcard@de182557cff45f2ca9b2b67a6b93be5917612a44
```

## 2. Non-goals

- Embedding or compiling the upstream Rust implementation.
- Exposing Rust lifetime, ownership, const-generic or `Result` types directly.
- Claiming optional ecosystem integrations before a Cangjie-native implementation and tests exist.
- Treating implementation similarity as proof of compatibility; fixed Cangjie vectors are required.

## 3. Architecture

| Layer | Packages | Responsibility |
|---|---|---|
| Wire core | `postcard4cj.core` | Varint, ZigZag, lengths, discriminants, primitive items, positions and errors |
| Public codec | `postcard4cj` | Encoder/decoder, codec interfaces and convenience functions |
| Structured model | `postcard4cj.serde_model` | Sequence, map, tuple, struct and enum operations |
| Flavors | `postcard4cj.flavors` | Fixed, growable, Extend, stream, size, COBS and CRC composition |
| Utilities | accumulator, fixint, IO, MaxSize packages | Framing, fixed-width values, streams and size bounds |
| Schema | legacy and NG Schema packages | Runtime-owned graph, formatting, traversal and stable keys |
| Dynamic | legacy and NG Dynamic packages | Schema-directed lossless values and JSON-compatible conversion |
| Modern facade | v2, v2_eio and v2_fixed packages | Postcard2-style API and Cangjie storage/IO adapters |
| Macros | `postcard_macro`, `derive_ng` | Codec, Schema and MaxSize generation |
| Tests | compatibility and `*_test` packages | Golden Vectors, malformed input and regression validation |

## 4. Wire invariants

- Unsigned integers use canonical variable-length encoding.
- Signed integers use ZigZag followed by variable-length encoding.
- Bool and Option discriminants accept only protocol-valid values.
- String, byte, sequence and map lengths use the Postcard length encoding.
- Struct fields and enum variants use declaration order.
- Float values preserve their binary payload.
- Exact decode rejects trailing bytes.
- Take-style decode returns unused bytes.
- COBS frames terminate with zero.
- CRC framing uses CRC32C/iSCSI and validates the appended checksum.

A wire-affecting change requires a fixed compatibility vector.

## 5. Cangjie substitutions

### Ownership

Owned `String` and `Array<UInt8>` values replace lifetime-bound borrowed strings and byte slices. Scratch arrays are caller-provided where temporary storage is needed.

### Errors

Cangjie exceptions replace generic Rust `Result` values while preserving explicit protocol, capacity, framing and unsupported-operation categories.

### Capacity

Runtime-capacity fixed vectors replace const-generic storage. Capacity failure is deterministic and observable.

### IO

Cangjie `ByteReader` and `ByteWriter` replace embedded-IO traits. Streaming APIs preserve the same wire bytes as array-based APIs.

### Schema

One runtime-owned Schema graph replaces separate static-reference and owned trees. Formatting, recursive traversal and stable keys remain observable and tested.

## 6. Flavor composition

1. The encoder emits canonical Postcard bytes.
2. A storage Flavor selects fixed buffer, growable array, Extend sink, stream writer or size counter.
3. COBS and CRC32C Flavors apply framing.
4. Finalization returns the selected output.

Deserialization Flavors provide slice, stream, decoded COBS and validated CRC sources. Remainder-aware functions retain bytes not consumed by the current message.

COBS output is constructed incrementally with at most a 254-byte pending segment. CRC32C is updated while bytes flow through the Flavor. Finalization avoids a second complete-message copy, `snapshot()` remains non-mutating, and nested middleware order is preserved.

## 7. Macro design

The five codec/Schema/MaxSize macro entry points parse declarations and generate interface extensions:

- `@Postcard`
- `@PostcardSchema`
- `@PostcardMaxSize`
- `@PostcardSchemaNg`
- `@PostcardMaxSizeNg`

Supported declaration boundary:

- non-generic structs
- exhaustive non-generic enums
- generic structs with one or more type parameters
- exhaustive generic enums with one or more type parameters
- declarations with or without pre-existing `where` upper bounds
- primitive, nested, `Option<T>` and `Array<T>` codec/Schema fields
- bounded MaxSize payload types

Generated generic parameter lists and constraints are rebuilt from identifier tokens. Existing upper bounds are read through the AST and merged with generated codec, Schema, or MaxSize requirements without redeclaring type parameters.

Named Schema entry points provide type, field, and enum-variant rename metadata:

- `@PostcardSchemaNamed[...]`
- `@PostcardSchemaNgNamed[...]`

Rename metadata changes Schema names only and does not change wire bytes.

Explicitly unsupported:

- non-exhaustive enum generation
- unbounded String/Array MaxSize fields

Unsupported declarations must produce an explicit compile-time diagnostic rather than invalid generated code.

## 8. Security and resource limits

Wire lengths are untrusted.

- Sequence and map decoders do not preallocate directly from a declared wire count.
- Initial allocation is capped by remaining input size.
- Truncated input fails before a complete value is returned.
- Invalid UTF-8, Rune, discriminants, varints, COBS and CRC input produces defined failures.
- Fixed-capacity outputs fail instead of exceeding configured capacity.

Every new length-prefixed decoder requires a malicious-length regression test.

## 9. Verification

Compatibility is validated entirely in Cangjie. The suite covers:

- primitive boundaries and malformed values
- records and compound values
- enum declaration order
- signed and unsigned 128-bit values
- COBS and CRC32C frames and remainder behavior
- fixed, growable, Extend and streaming paths
- Schema, Dynamic and JSON-compatible behavior
- generated structs and enums
- single- and multi-parameter generic structs and enums
- existing `where` bound merging
- Schema rename metadata
- malicious collection lengths

CI runs:

```bash
cjpm build -V
cjpm test -V
```

under both Cangjie 1.0.5 and 1.1.3.

Latest result on both versions: **189 passed, 0 failed, 0 skipped, 0 errors**.

The STS quality job also generates coverage reports, runs native benchmarks, checks lint errors, and validates the release bundle.

## 10. Release model

The project follows the cj-awesome dual-version model:

- `main` is the Cangjie 1.0.5 adaptation baseline.
- `feat/postcard4cj-1.1.3` carries the Cangjie 1.1.3 adaptation.
- Published artifacts identify their supported compiler line.
- Logic remains shared whenever both compilers accept the same source.

## 11. Change requirements

A behavioral change is complete only when:

1. Source remains pure Cangjie.
2. LTS and STS build and test, or divergence is isolated and documented.
3. Positive and relevant negative tests exist.
4. Wire changes include a Golden Vector.
5. Public API changes update `doc/feature_api.md`, `doc/feature_api.en.md`, and `API_COMPATIBILITY.md`.
6. User-visible changes update `CHANGELOG.md`.
7. New ownership, capacity or IO substitutions are documented.
8. Chinese entry documentation remains consistent with the English source-of-truth documents.

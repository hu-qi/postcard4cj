# postcard4cj Design

## 1. Purpose

postcard4cj is a pure Cangjie implementation of the Postcard binary wire format and the observable behavior of the upstream Postcard workspace.

The design goals are:

1. Preserve Postcard wire compatibility.
2. Provide Cangjie-native APIs rather than wrapping or executing Rust code.
3. Support Cangjie LTS 1.0.5 and STS 1.1.3.
4. Keep fixed-buffer, growable, streaming, COBS, CRC32C, schema, dynamic-value, and macro use cases available.
5. Reject malformed or adversarial input deterministically without untrusted eager allocation.
6. Document every deliberate language-level substitution.

The upstream behavior baseline is:

```text
jamesmunns/postcard@de182557cff45f2ca9b2b67a6b93be5917612a44
```

## 2. Non-goals

- Embedding or compiling the upstream Rust implementation.
- Exposing Rust ownership, lifetime, const-generic, or `Result` types directly.
- Claiming support for optional ecosystem adapters before a Cangjie-native design is implemented and tested.
- Treating implementation similarity as proof of wire compatibility; compatibility must be demonstrated by Cangjie tests.

## 3. Repository architecture

The project is one Cangjie package with multiple source packages under `src/`.

| Layer | Main packages | Responsibility |
|---|---|---|
| Wire core | `postcard4cj.core` | Varint, ZigZag, primitive encoding/decoding, positions, lengths, discriminants, errors |
| Public codec API | `postcard4cj` | `PostcardEncoder`, `PostcardDecoder`, encode/decode interfaces and convenience functions |
| Serde-style model | `postcard4cj.serde_model` | Structured serializer/deserializer operations and compound value handling |
| Flavors | `postcard4cj.flavors` | Fixed, growable, Extend, size, COBS, CRC32C, and source/sink composition |
| Utility modules | `postcard4cj.accumulator`, `postcard4cj.fixint`, `postcard4cj.io`, `postcard4cj.max_size` | Incremental framing, fixed-width integers, IO and maximum-size calculation |
| Schema | `postcard4cj.schema`, `postcard4cj.schema_ng` | Runtime-owned schema graph, formatting, traversal, stable keys |
| Dynamic values | `postcard4cj.dynamic`, `postcard4cj.dynamic_ng` | Schema-directed lossless values and JSON-compatible conversion |
| Modern API | `postcard4cj.v2`, `postcard4cj.v2_eio`, `postcard4cj.v2_fixed` | Postcard2-style facade, IO and fixed-capacity adapters |
| Macros | `postcard4cj.postcard_macro`, `postcard4cj.derive_ng` | Codec, Schema and MaxSize code generation |
| Compatibility tests | `postcard4cj.compatibility` and test packages | Golden Vectors, malformed-input behavior and regression coverage |

Detailed upstream-to-Cangjie mappings are maintained in `MIGRATION.md` and `API_COMPATIBILITY.md`.

## 4. Wire-format invariants

The following behavior is protocol-critical:

- Unsigned integers use canonical variable-length encoding.
- Signed integers use ZigZag transformation followed by variable-length encoding.
- Bool and Option discriminants accept only valid protocol values.
- Sequence, map, string and byte lengths use the Postcard length representation.
- Struct fields and enum variants are encoded in declaration order.
- Float payloads preserve their binary representation.
- Exact decoding rejects trailing input; take-style decoding returns the unused remainder.
- COBS frames terminate with a zero delimiter.
- CRC32C uses the iSCSI polynomial and validates the appended checksum.

Changes to these invariants require new Golden Vectors and a compatibility-document update.

## 5. Cangjie language substitutions

### 5.1 Ownership and borrowing

Cangjie-owned `String` and `Array<UInt8>` values replace lifetime-bound borrowed Rust strings and byte slices. Caller-provided scratch arrays are used where temporary storage is required.

### 5.2 Errors

Cangjie exceptions represent serialization and deserialization failures. Error categories remain explicit so callers can distinguish malformed input, insufficient output capacity, unsupported operations, CRC failure, and other protocol states.

### 5.3 Capacity

Runtime-capacity fixed vectors replace Rust const-generic capacity types. Capacity failure remains observable and deterministic.

### 5.4 IO

Cangjie `ByteReader` and `ByteWriter` interfaces replace versioned embedded-IO traits. Streaming APIs must not alter the Postcard wire representation.

### 5.5 Schema ownership

A runtime-owned schema graph replaces separate static-reference and owned schema trees. Stable type/path keys and recursive traversal preserve observable schema behavior.

## 6. Flavor composition

Serialization writes protocol bytes through a Flavor abstraction. Storage and transformation are separated:

1. The encoder emits canonical Postcard bytes.
2. A storage Flavor chooses fixed buffer, growable array, Extend sink, stream writer, or size counter.
3. COBS and CRC32C Flavors transform or append framing data.
4. Finalization returns the selected output representation.

Deserialization uses source Flavors for slices, streams, decoded COBS frames and validated CRC32C messages. Remainder-aware functions preserve bytes not consumed by the current message.

Current COBS and CRC32C middleware may buffer intermediate data. Incremental lower-allocation transformation remains a performance optimization target; it must not change the public wire behavior.

## 7. Macro design

The macro packages parse struct and enum declarations and generate extensions implementing the required interfaces.

Supported boundary:

- non-generic structs and exhaustive enums
- generic structs with one or more type parameters when no existing `where` clause is present
- primitive, nested codec type, `Option<T>` and `Array<T>` fields for codec/schema generation
- bounded field types for maximum-size generation

Generic parameter lists and generated constraints are rebuilt from identifier tokens. Formatting and punctuation tokens are never treated as type names.

Not yet supported:

- generic enums
- merging pre-existing generic constraints
- rename and related attributes
- unbounded fields in MaxSize generation

Unsupported declarations must produce explicit macro diagnostics rather than silently generating an invalid codec.

## 8. Security and resource limits

Wire lengths are untrusted.

- Sequence and map decoders do not preallocate directly from the declared wire count.
- Initial allocation is capped by remaining input size.
- Truncated input fails before constructing a complete value.
- Invalid UTF-8, Unicode scalar values, discriminants, varints, COBS frames, and CRC values produce defined errors.
- Fixed-capacity outputs fail instead of reallocating beyond their configured capacity.

Any new length-prefixed decoder must include a malicious-length regression test.

## 9. Compatibility verification

Compatibility is validated entirely in Cangjie.

The test suite includes:

- primitive boundary vectors
- records, compound values and enum declaration order
- signed and unsigned 128-bit values
- COBS and CRC32C framing
- frame/message remainder behavior
- macro-generated codecs, schemas and maximum sizes
- single- and multi-parameter generic structs
- malformed and truncated input
- malicious sequence/map lengths

CI must run both:

```bash
cjpm build -V
cjpm test -V
```

under Cangjie LTS 1.0.5 and STS 1.1.3.

## 10. Release model

The project follows the cj-awesome dual-version model:

- `main` remains the shared source baseline.
- LTS release branches use `postcard4cj_lt_<version>` naming.
- STS release branches use `postcard4cj_st_<version>` naming when version-specific adaptation is necessary.
- Published artifacts must identify the supported Cangjie release line.
- Logic should remain shared whenever both compilers accept the same source.

## 11. Change requirements

A behavioral change is complete only when:

1. The source is pure Cangjie.
2. LTS and STS build and test successfully, or the incompatibility is explicitly isolated to a release branch.
3. New behavior has positive and negative tests.
4. Wire-affecting behavior has a fixed compatibility vector.
5. Public API changes update `doc/feature_api.md` and `API_COMPATIBILITY.md`.
6. User-visible changes update `CHANGELOG.md`.
7. Ownership, capacity or IO substitutions are documented when relevant.

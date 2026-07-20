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

## Acceptance criteria

1. Every upstream workspace crate has a documented Cangjie counterpart.
2. All public upstream behavior has an equivalent or an explicitly documented language-level substitution.
3. Primitive and composite Golden Vectors match Rust Postcard byte-for-byte.
4. Invalid bool, UTF-8, char, option, enum, varint, encoding, CRC, and truncated-input vectors return the matching error category.
5. Fixed-buffer, growable-buffer, stream, COBS, CRC32C, accumulator, and remainder APIs pass tests.
6. Struct/enum/schema/max-size macros compile and pass end-to-end tests.
7. Dynamic schema-directed round trips pass for JSON-compatible values.
8. The complete Cangjie workspace builds and tests under CI.
9. MIT and Apache-2.0 licenses and upstream attribution are present.
10. README no longer carries an “in progress” warning.

## Phase 1 foundation

Currently implemented and tested:

- integer encodings including `BigInt`-backed Rust-compatible 128-bit integers
- Bool, floats, bytes, UTF-8 strings, Rune, Option, Unit
- sequences, tuple-2, ordered map entries, enum indices
- fixed and growable output buffers
- COBS and CRC32C helpers
- basic non-generic struct/enum macro
- Rust 1.1.3 Golden Vector oracle

These capabilities are only the initial compatibility layer.

# postcard4cj

A Cangjie port of the complete [`jamesmunns/postcard`](https://github.com/jamesmunns/postcard) workspace.

> **Status: full workspace coverage implemented; compatibility audit in progress.**
>
> Every upstream workspace crate now has a Cangjie counterpart. The branch builds under Cangjie 1.1.3 and currently passes 144 Cangjie tests plus the Rust `postcard = 1.1.3` interoperability oracle. The Draft PR remains open while API parity, language-level substitutions, generic derive support, and the complete upstream negative-test matrix are audited.

## Upstream baseline

```text
jamesmunns/postcard@de182557cff45f2ca9b2b67a6b93be5917612a44
```

## Workspace mapping

| Upstream crate | Cangjie counterpart |
|---|---|
| `postcard-core` | `postcard4cj.core` |
| `postcard` | `postcard4cj`, `postcard4cj.serde_model`, `postcard4cj.flavors`, `postcard4cj.accumulator`, `postcard4cj.fixint`, `postcard4cj.io`, `postcard4cj.max_size` |
| `postcard-derive` | `postcard4cj.postcard_macro` |
| `postcard-derive-ng` | `postcard4cj.derive_ng` |
| `postcard-schema` | `postcard4cj.schema` |
| `postcard-schema-ng` | `postcard4cj.schema_ng` |
| `postcard-dyn` | `postcard4cj.dynamic` |
| `postcard-dyn-ng` | `postcard4cj.dynamic_ng` |
| `postcard2` | `postcard4cj.v2` |
| `postcard2-eio` | `postcard4cj.v2_eio` |
| `postcard2-heapless` | `postcard4cj.v2_fixed` |

See [`MIGRATION.md`](MIGRATION.md) for the detailed coverage and acceptance matrix.

## Implemented capabilities

### Wire and data model

- all Postcard primitive wire items through signed and unsigned 128-bit integers
- canonical Varint and ZigZag encoding
- Bool, floats, Rune, UTF-8 strings, byte arrays, Option, Unit
- sequences, maps, tuples, structs, and all enum variant forms
- exact decoding and take-with-remainder decoding
- all 16 Postcard 1.x error categories

### Flavors and storage

- growable Array output
- caller-provided fixed Slice output
- generic streaming Extend sink
- serialized-size counting
- composable COBS and CRC32C serialization/deserialization
- Slice, stream, COBS, and CRC sources with remainder semantics
- runtime-capacity fixed byte vector corresponding to `heapless::Vec<u8, B>`

### Higher-level modules

- chunked COBS accumulator
- fixed-width LE/BE integer codecs for 16/32/64/128-bit values
- serializer/deserializer model and helper APIs
- legacy stream IO helpers
- separate postcard2-style API and error model
- postcard2 EIO and fixed-capacity adapters

### Schema and dynamic values

- complete Postcard Schema data model
- Schema values serialized with Postcard
- runtime-owned Schema tree and recursive type discovery
- pseudo-Rust Schema formatting
- upstream-compatible FNV-1a type/path keys
- lossless schema-directed Dynamic values
- arbitrary-key Dynamic maps
- explicit `None` versus `Some(Unit)` representation
- `serde_json::Value`-compatible JSON model and conversion rules
- legacy and next-generation schema/dynamic namespaces

### Macros

- `@Postcard` codec generation
- `@PostcardSchema` and `@PostcardMaxSize`
- `@PostcardSchemaNg` and `@PostcardMaxSizeNg`
- struct and enum declaration-order semantics

## Verification

GitHub Actions installs Cangjie 1.1.3 (`cjnative`) on Ubuntu 22.04 using the configured OBS callback mirror and verifies the SDK checksum.

Latest validated result:

- `cjpm build -V`: success
- `cjpm test -V`: **144 passed, 0 failed, 0 skipped, 0 errors**
- Rust Oracle `cargo test`: success
- Rust Oracle `cargo run`: success

```bash
cjpm build -V
cjpm test -V

cd interop/rust-oracle
cargo test
cargo run
```

## Development branch and PR

```text
feat/full-postcard-port
```

Draft pull request: [#1 feat: port complete Postcard workspace to Cangjie](https://github.com/hu-qi/postcard4cj/pull/1)

## Remaining audit work

- compare every upstream public API against its Cangjie counterpart
- expand invalid-input and edge-case parity against upstream tests
- add generic struct/enum macro support where the Cangjie macro/type system permits it
- document all ownership, borrowing, const-generic, and embedded-IO substitutions
- audit optional upstream integrations such as chrono, UUID, nalgebra, fixed, defmt, and heapless version adapters
- optimize buffered COBS/CRC middleware toward the upstream zero-extra-allocation design
- finalize release documentation and remove the Draft status only after the compatibility matrix is signed off

## License

Licensed under either:

- Apache License, Version 2.0 (`LICENSE-APACHE`)
- MIT License (`LICENSE-MIT`)

`NOTICE` records the upstream attribution and the Cangjie-language modifications.

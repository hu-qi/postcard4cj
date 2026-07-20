# postcard4cj

A pure Cangjie implementation of the complete [`jamesmunns/postcard`](https://github.com/jamesmunns/postcard) workspace behavior.

> **Status: all 11 workspace crates have Cangjie counterparts; compatibility hardening and release preparation continue.**
>
> The library, tests, tooling, and CI contain no Rust implementation. Wire compatibility is verified by fixed Postcard Golden Vectors and behavior tests implemented entirely in Cangjie.

## Supported Cangjie versions

- LTS: Cangjie 1.0.5
- STS: Cangjie 1.1.3

The package declares 1.0.5 as its minimum compiler version. CI builds and tests the same source tree on both release lines.

## Upstream baseline

```text
jamesmunns/postcard@de182557cff45f2ca9b2b67a6b93be5917612a44
```

The upstream repository defines the protocol and observable behavior being implemented. It is not a runtime, build, or test dependency of postcard4cj.

## Pure Cangjie policy

The repository accepts only Cangjie implementation code:

- no `.rs` files
- no `Cargo.toml` or `Cargo.lock`
- no Rust toolchain configuration
- no Rust build or test workflow
- no foreign-language runtime dependency for serialization or deserialization

CI enforces this policy before running the LTS and STS build/test matrix.

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

## Implemented capabilities

### Wire and data model

- all Postcard primitive wire items through signed and unsigned 128-bit integers
- canonical Varint and ZigZag encoding
- Bool, floats, Rune, UTF-8 strings, byte arrays, Option, Unit
- sequences, maps, tuples, structs, and all enum variant forms
- exact decoding and take-with-remainder decoding
- all 16 Postcard 1.x error categories
- allocation caps for untrusted sequence and map lengths

### Flavors and storage

- growable Array output
- caller-provided fixed Slice output
- generic streaming Extend sink
- serialized-size counting
- composable COBS and CRC32C serialization/deserialization
- COBS/CRC convenience APIs with remainder handling
- Slice, stream, COBS, and CRC sources
- runtime-capacity fixed byte vectors

### Higher-level modules

- chunked COBS accumulator
- fixed-width LE/BE integer codecs for 16/32/64/128-bit values
- serializer/deserializer model and helper APIs
- stream IO helpers through Cangjie `ByteReader` and `ByteWriter`
- separate postcard2-style API and error model
- postcard2 EIO and fixed-capacity adapters

### Schema and dynamic values

- complete Postcard Schema data model
- Schema values serialized with Postcard
- runtime-owned Schema tree and recursive type discovery
- Schema formatting
- upstream-compatible FNV-1a type/path keys
- lossless schema-directed Dynamic values
- arbitrary-key Dynamic maps
- explicit `None` versus `Some(Unit)` representation
- JSON-compatible value model and conversion rules
- legacy and next-generation schema/dynamic namespaces

### Macros

- `@Postcard` codec generation
- `@PostcardSchema` and `@PostcardMaxSize`
- `@PostcardSchemaNg` and `@PostcardMaxSizeNg`
- struct and enum declaration-order semantics
- all five macro entry points support generic structs and generic enums with one or more type parameters when no pre-existing `where` clause is present
- existing-constraint merging and rename attributes remain under audit

## Verification

For each release line CI runs:

```bash
cjpm build -V
cjpm test -V
```

Latest validation on both Cangjie 1.0.5 and 1.1.3:

- pure-source policy: passed
- `cjpm build -V`: passed
- `cjpm test -V`: **178 passed, 0 failed, 0 skipped, 0 errors**

The suite covers fixed Golden Vectors, malformed input, COBS/CRC32C framing, remainder behavior, allocation regressions, and generated struct/enum codecs, schemas, and maximum sizes, including multi-parameter generic declarations.

## Documentation

- [Design](doc/design.md)
- [Feature and API guide](doc/feature_api.md)
- [Functional test coverage](doc/cjcov/README.md)
- [Migration matrix](MIGRATION.md)
- [Public API compatibility](API_COMPATIBILITY.md)
- [Changelog](CHANGELOG.md)
- [Upstream open-source record](README.OpenSource)
- [Test layout](test/README.md)

## Remaining compatibility work

- complete the line-by-line public API audit
- merge existing generic `where` constraints safely in generated extensions
- add rename and related macro attributes
- expand malformed-input and edge-case parity tests
- provide Cangjie-native adapters or explicit exclusions for optional ecosystem integrations
- optimize buffered COBS/CRC middleware toward incremental low-allocation operation
- add benchmark, center-repository publication, and release documentation

## License

Licensed under either:

- Apache License, Version 2.0 (`LICENSE-APACHE`)
- MIT License (`LICENSE-MIT`)

`NOTICE` records upstream attribution and the Cangjie-language implementation.

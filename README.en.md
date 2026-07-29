# postcard4cj

English | [简体中文](README.md)

A pure Cangjie implementation of the complete [`jamesmunns/postcard`](https://github.com/jamesmunns/postcard) workspace behavior.

> **Status: release candidate.** All 11 upstream workspace crates have documented Cangjie counterparts, the repository contains no Rust implementation, and the same source tree passes the complete LTS/STS quality matrix.

## Supported Cangjie versions

- LTS: Cangjie 1.0.5
- STS: Cangjie 1.1.3

The default `main` branch is the Cangjie 1.0.5 adaptation baseline. The
Cangjie 1.1.3 adaptation is maintained on:

- `feat/postcard4cj-1.1.3`

## Upstream baseline

```text
jamesmunns/postcard@118d274cf46ee8097e7a4aae0c12a801c7aea8cc
```

The upstream repository defines the protocol and observable behavior. It is not a runtime, build, or test dependency of postcard4cj.

## Pure Cangjie policy

CI rejects Rust source, Cargo manifests, Rust toolchain configuration, and `.cargo` before compiling. Serialization, deserialization, tests, compatibility vectors, benchmarks, coverage, and packaging are implemented with Cangjie tooling only.

## Workspace mapping

| Upstream crate | Cangjie counterpart |
|---|---|
| `postcard-core` | `postcard4cj.core` |
| `postcard` | `postcard4cj` plus flavors, accumulator, fixint, IO, and MaxSize packages |
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

### Wire model and APIs

- signed and unsigned integer wire items through 128-bit
- canonical Varint and ZigZag encoding
- Bool, Float32/64, Rune, UTF-8 String, bytes, Option, and Unit
- sequences, maps, tuples, structs, and every exhaustive enum payload form
- exact decode and decode-with-remainder APIs
- all 16 Postcard 1.x error categories
- allocation caps for untrusted collection lengths
- fixed, growable, Extend, stream, COBS, CRC32C, accumulator, and fixed-capacity paths
- postcard2-style facade, EIO, and fixed-capacity adapters

### Framing and allocation behavior

- incremental COBS block construction with a fixed 254-byte pending segment
- incremental CRC32C checksum updates
- non-mutating `snapshot()` and composable Flavor finalization
- COBS/CRC exact and remainder helpers

### Schema and dynamic values

- complete runtime-owned Schema model and Postcard codec
- formatting, recursive type discovery, and upstream-compatible FNV keys
- lossless Dynamic values and JSON-compatible conversion
- arbitrary-key maps and distinct `None` / `Some(Unit)` values
- legacy and next-generation Schema/Dynamic namespaces

### Macros

- `@Postcard`
- `@PostcardSchema`
- `@PostcardMaxSize`
- `@PostcardSchemaNg`
- `@PostcardMaxSizeNg`
- `@PostcardSchemaNamed[...]`
- `@PostcardSchemaNgNamed[...]`

The five codec/Schema/MaxSize entry points support non-generic and generic structs and exhaustive enums with one or more type parameters. Existing `where` upper bounds are preserved and merged with generated Postcard bounds.

The named Schema macros provide Cangjie-native rename metadata for type names, struct fields, and enum variants without changing wire bytes. Example:

```cangjie
@PostcardSchemaNamed["wire_record", "id=wire_id"]
public struct Record {
    public let id: UInt32
}
```

Non-exhaustive enums are rejected because a stable variant set cannot be derived. MaxSize generation rejects unbounded String and Array fields.

## Verification

The latest complete CI run validates both compiler lines and the STS quality gates:

- pure-source policy: passed
- Cangjie 1.0.5 build: passed
- Cangjie 1.0.5 tests: **197 passed, 0 failed, 0 skipped, 0 errors**
- Cangjie 1.1.3 build: passed
- Cangjie 1.1.3 tests: **197 passed, 0 failed, 0 skipped, 0 errors**
- `cjcov` HTML/XML/JSON reports: generated
- source-line coverage across all instrumented `src`: **66.76%**
- runtime-library coverage excluding test, benchmark, and compile-time macro packages: **71.98%**
- native benchmark cases: **6 passed**
- `cjpm bundle`: passed
- package artifact: `postcard4cj-0.1.0.cjp`

The test suite covers Golden Vectors, malformed and truncated input, malicious lengths, COBS/CRC framing, remainder semantics, Flavor composition, Schema/Dynamic behavior, generic constraints, and rename metadata.

## Documentation

### Chinese

- [中文 README](README.md)
- [快速上手](doc/quickstart.zh-CN.md)
- [功能与 API 指南](doc/feature_api.md)
- [从 Rust Postcard 迁移](doc/migration.zh-CN.md)

### English

- [Design](doc/design.en.md)
- [Feature and API guide](doc/feature_api.en.md)
- [Coverage report](doc/cjcov/README.md)
- [Complete LLT report (Chinese)](doc/LLT.md)
- [Cangjie 1.1.3 LLT report (Chinese)](doc/LLT-1.1.3.md)
- [Benchmarks](doc/benchmark.md)
- [Optional integration decisions](doc/optional_integrations.en.md)
- [Migration matrix](MIGRATION.md)
- [Public API compatibility](API_COMPATIBILITY.md)
- [Changelog](CHANGELOG.md)
- [Open-source record](README.OpenSource)
- [Test layout](test/README.md)

## Release operations

The source package is bundle-ready. Actual publication to the Cangjie center repository requires a publisher token in a local, gitignored `cangjie-repo.toml`. AtomGit mirroring likewise requires a valid external credential and reachable AtomGit service; credentials are never stored in this repository.

## License

Licensed under either:

- Apache License, Version 2.0 (`LICENSE-APACHE`)
- MIT License (`LICENSE-MIT`)

`NOTICE` records upstream attribution and the independent Cangjie implementation.

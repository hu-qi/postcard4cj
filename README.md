# postcard4cj

A Cangjie port of the complete [`jamesmunns/postcard`](https://github.com/jamesmunns/postcard) repository.

> **Status: active full-port work. Not release-ready.**
>
> The project now includes a dedicated wire/core layer, composable Flavors, a Cangjie-native serializer/deserializer data model, a COBS accumulator, fixed-width integer codecs, and maximum-size calculation. Schema, dynamic values, next-generation derives, stream adapters, and the separate `postcard2` compatibility layer remain incomplete.

## Port baseline

The port is tracked against upstream `main` commit:

```text
de182557cff45f2ca9b2b67a6b93be5917612a44
```

The upstream repository contains 11 workspace crates:

- `postcard`
- `postcard-core`
- `postcard-derive`
- `postcard-derive-ng`
- `postcard-dyn`
- `postcard-dyn-ng`
- `postcard-schema`
- `postcard-schema-ng`
- `postcard2`
- `postcard2-eio`
- `postcard2-heapless`

Completion means providing Cangjie-native equivalents for the complete workspace behavior: wire primitives, serializer/deserializer data model, composable flavors, fixed and dynamic storage, stream IO, accumulators, fixed-width integers, max-size derivation, schema/reflection, dynamic values, and the postcard2 adapters.

See [`MIGRATION.md`](MIGRATION.md) for the current coverage matrix and acceptance criteria.

## Implemented and validated

- `postcard4cj.core`
  - Postcard primitive wire model through 128-bit integers
  - stable Postcard error categories
  - length/discriminant helpers and remainder handling
- `postcard4cj.flavors`
  - growable and fixed storage
  - size counting
  - composable COBS and CRC32C
  - slice/COBS/CRC deserialization sources
- `postcard4cj.serde_model`
  - `PostcardSerialize` / `PostcardDeserialize<T>`
  - primitive, Option, unit, newtype, tuple, struct, sequence, map, and enum variant APIs
  - exact, fixed-buffer, flavored, size and remainder helpers
- `postcard4cj.accumulator`
  - chunked COBS frame collection and typed deserialization
- `postcard4cj.fixint`
  - fixed-width LE/BE Int/UInt 16, 32, 64 and 128-bit codecs
- `postcard4cj.max_size`
  - primitive and composite maximum-size rules
- compatibility foundation
  - basic `@Postcard` struct/enum macro
  - Rust `postcard = 1.1.3` Golden Vector oracle

The latest code-bearing Cangjie validation completed successfully in Actions run `29719455828`.

## Development branch and PR

```text
feat/full-postcard-port
```

Draft pull request: [#1 feat: port complete Postcard workspace to Cangjie](https://github.com/hu-qi/postcard4cj/pull/1)

The pull request remains Draft until the complete migration matrix passes.

## Verification

GitHub Actions runs Cangjie 1.1.3 (`cjnative`) on Ubuntu 22.04 and verifies the Rust interoperability oracle.

```bash
cjpm build -V
cjpm test -V

cd interop/rust-oracle
cargo test
cargo run
```

## Remaining major work

- schema model, stable type keys and owned schema formatting
- schema and MaxSize macro generation
- dynamic schema-directed values and JSON conversion
- generic Extend and stream reader/writer Flavors
- `postcard2`, EIO and fixed-capacity adapter packages
- complete upstream negative and compatibility test matrix

## License

The port follows the upstream dual-license model: MIT OR Apache-2.0. Upstream attribution and license files are retained with the port.

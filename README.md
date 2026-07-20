# postcard4cj

A Cangjie port of the complete [`jamesmunns/postcard`](https://github.com/jamesmunns/postcard) repository.

> **Status: active full-port work. Not release-ready.**
>
> The first implementation pass proved byte compatibility with Rust `postcard = 1.1.3` for core wire types, COBS, CRC32C, fixed buffers, and basic struct/enum macros. That is only the wire/core layer—not the complete upstream repository.

## Port baseline

The port is tracked against upstream `main` commit:

```text
de182557cff45f2ca9b2b67a6b93be5917612a44
```

The upstream repository currently contains 11 workspace crates:

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

See [`MIGRATION.md`](MIGRATION.md) for the coverage matrix and acceptance criteria.

## Development branch

Full implementation work is submitted to:

```text
feat/full-postcard-port
```

The current wire-compatible prototype is retained there as the Phase 1 foundation. It must not be interpreted as completion of the full port.

## Verification targets

- Cangjie 1.1.3 on Ubuntu 22.04
- byte-for-byte interoperability against Rust `postcard = 1.1.3`
- upstream-compatible negative/error vectors
- workspace-wide Cangjie build and tests
- stream, fixed-buffer, COBS, CRC32C, schema, dynamic-value, and macro integration tests

## License

The port follows the upstream dual-license model: MIT OR Apache-2.0. Upstream attribution and license files are retained with the port.

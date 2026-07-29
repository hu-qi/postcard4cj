# Optional integration decisions

[简体中文](optional_integrations.md) | English

The upstream Postcard workspace exposes optional integrations for Rust ecosystem types. postcard4cj is a pure Cangjie library and does not embed Rust crates merely to reproduce feature names. This document records the release decision for every upstream integration category.

## General adapter contract

A Cangjie application type can participate in Postcard by implementing:

- `PostcardEncode`
- `PostcardDecode<T>`
- optionally `PostcardSchema<T>` or `PostcardSchemaNg<T>`
- optionally `PostcardMaxSize` when the type has a finite encoded maximum

Adapters preserve the Postcard wire representation of the logical value. They are maintained in the package that owns or selects the Cangjie-native type, avoiding a dependency from postcard4cj to unrelated ecosystem libraries.

## Decisions

| Upstream integration | Cangjie decision | Status |
|---|---|---|
| UUID | Encode the canonical 16-byte value through an application adapter. postcard4cj does not select a third-party UUID package. | Supported through public adapter interfaces; no built-in dependency |
| chrono/date-time | Encode an explicitly selected numeric or structured time representation. Time zones and calendar semantics remain owned by the application type. | Supported through public adapter interfaces; no built-in dependency |
| nalgebra matrices/vectors | Encode dimensions and scalar elements using sequence/tuple APIs. postcard4cj does not select a matrix package. | Supported through public adapter interfaces; no built-in dependency |
| fixed-point numbers | Encode the underlying signed/unsigned integer according to the selected scale contract. | Supported through public adapter interfaces; no built-in dependency |
| defmt diagnostics | Diagnostic formatting is not part of the wire format. Cangjie exceptions and ordinary formatting are used. | Explicitly excluded as a Rust-only diagnostics integration |
| serde-big-array | Cangjie `Array<T>` and explicit fixed-capacity wrappers use the normal sequence/fixed APIs and do not need a serde workaround. | Native core API; separate integration unnecessary |
| heapless 0.7/0.8/0.9 aliases | `FixedByteVec` and `FixedVecFlavor` provide runtime-capacity equivalents without importing versioned Rust containers. | Implemented Cangjie substitution |
| embedded-io 0.4/0.6 aliases | `ByteReader` and `ByteWriter` provide a stable Cangjie IO contract without versioned Rust traits. | Implemented Cangjie substitution |

## Compatibility boundary

These decisions claim wire-level capability, not source-level compatibility with Rust type names. A native adapter must document its chosen logical representation and include Golden Vector tests when interoperability with another implementation is required.

No optional integration may add `.rs`, Cargo, a Rust toolchain, or a Rust runtime dependency to postcard4cj.

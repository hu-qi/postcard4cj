# Changelog

All notable changes to postcard4cj are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses semantic versioning for published packages.

## [Unreleased]

### Added

- Pure Cangjie implementations corresponding to all 11 upstream Postcard workspace crates.
- Postcard primitive, compound, schema, dynamic-value, framing, IO, and fixed-capacity APIs.
- COBS and CRC32C serialization/deserialization with remainder helpers.
- Cangjie macro generation for codecs, schemas, and maximum serialized size.
- Generic struct support for one or more type parameters when no pre-existing `where` clause is present.
- Pure Cangjie Golden Vector and malformed-input compatibility tests.
- CI enforcement rejecting Rust sources, Cargo files, Rust toolchain files, and `.cargo` configuration.
- Cangjie LTS 1.0.5 and STS 1.1.3 validation matrix.

### Changed

- Replaced Rust Oracle validation with fixed compatibility vectors implemented entirely in Cangjie.
- Capped initial sequence and map allocations derived from untrusted wire lengths.
- Rebuilt generated generic parameter lists and constraints from identifier tokens to support multiple parameters safely.

### Removed

- Rust Oracle source code, Cargo manifests, Cargo lockfile, and Rust GitHub Actions workflow.

## [0.1.0] - Unreleased

Initial public release preparation.

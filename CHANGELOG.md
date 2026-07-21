# Changelog

All notable changes to postcard4cj are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and published packages use semantic versioning.

## [Unreleased]

### Added

- Pure Cangjie implementations corresponding to all 11 upstream Postcard workspace crates.
- Postcard primitive, compound, Schema, dynamic-value, framing, IO, and fixed-capacity APIs.
- COBS and CRC32C serialization/deserialization with remainder helpers.
- Codec, Schema, NG Schema, MaxSize, and NG MaxSize macro generation.
- Generic struct and generic enum support for one or more type parameters when no pre-existing `where` clause is present.
- Pure Cangjie Golden Vector, malformed-input, remainder, and malicious-length tests.
- Cangjie LTS 1.0.5 and STS 1.1.3 build/test matrix.
- cj-awesome-aligned design, feature/API, functional coverage, test-layout, changelog, and open-source attribution documents.

### Changed

- Replaced Rust Oracle validation with fixed compatibility vectors implemented entirely in Cangjie.
- Declared Cangjie 1.0.5 as the minimum compiler version.
- Capped initial sequence and map allocations derived from untrusted wire lengths.
- Rebuilt generated generic parameter lists and constraints from identifier tokens to support multiple parameters safely.
- Expanded all five macro entry points from generic structs to generic structs and exhaustive generic enums.

### Removed

- Rust Oracle source code, Cargo manifests, Cargo lockfile, Rust toolchain configuration, and Rust GitHub Actions workflow.

### Verified

- Cangjie 1.0.5: build passed; 178 tests passed.
- Cangjie 1.1.3: build passed; 178 tests passed.
- Pure-source policy: passed on both matrix jobs.

## [0.1.0] - Unreleased

Initial public release preparation.

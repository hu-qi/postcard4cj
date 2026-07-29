# Changelog

All notable changes to postcard4cj are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and published packages use semantic versioning.

## [Unreleased]

### Added

- Pure Cangjie implementations corresponding to all 11 upstream Postcard workspace crates.
- Postcard primitive, compound, Schema, dynamic-value, framing, IO, and fixed-capacity APIs.
- COBS and CRC32C serialization/deserialization with remainder helpers.
- Caller-selected CRC32 digests with CRC32C/iSCSI compatibility helpers.
- enum-map v3 compatible fixed-array Schema and MaxSize adapters.
- Codec, Schema, NG Schema, MaxSize, and NG MaxSize macro generation.
- Generic struct and exhaustive generic enum support for one or more type parameters.
- AST-based merging of pre-existing generic `where` upper bounds with generated Postcard constraints.
- Cangjie-native Schema type, field, and enum-variant rename metadata through named legacy and NG Schema macros.
- Pure Cangjie Golden Vector, malformed-input, remainder, malicious-length, generic-bound, and rename tests.
- Cangjie LTS 1.0.5 and STS 1.1.3 build/test matrix.
- Native coverage, benchmark, lint-diagnostics, and release-bundle quality tasks.
- Chinese README, quick-start guide, API guide, and Rust-to-Cangjie migration guide.
- cj-awesome-aligned design, feature/API, functional coverage, benchmark, test-layout, changelog, and open-source attribution documents.

### Changed

- Replaced Rust Oracle validation with fixed compatibility vectors implemented entirely in Cangjie.
- Declared Cangjie 1.0.5 as the minimum compiler version.
- Capped initial sequence and map allocations derived from untrusted wire lengths.
- Rebuilt generated generic parameter lists and constraints from identifier tokens to support multiple parameters safely.
- Expanded all five macro entry points from generic structs to generic structs and exhaustive generic enums.
- Changed COBS serialization to incremental block construction with at most a 254-byte pending segment.
- Changed CRC32C serialization to incremental checksum updates without a second full-message copy during finalization.
- Preserved non-mutating Flavor `snapshot()` semantics and nested middleware order.
- Updated English design, migration, compatibility, and API documentation to match the final release-candidate implementation.

### Removed

- Rust Oracle source code, Cargo manifests, Cargo lockfile, Rust toolchain configuration, and Rust GitHub Actions workflow.

### Verified

- Cangjie 1.0.5: build passed; 197 tests passed.
- Cangjie 1.1.3: build passed; 197 tests passed.
- Pure-source policy: passed on both matrix jobs.
- `cjcov` HTML/XML/JSON reports generated.
- All instrumented `src` line coverage: 66.76%.
- Runtime-library line coverage: 71.98%.
- Native benchmarks: 6/6 passed.
- `cjpm bundle --skip-lint`: passed.
- Package artifact: `postcard4cj-0.1.0.cjp`.

## [0.1.0] - Unreleased

Initial public release preparation.

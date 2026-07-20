# LLT Coverage Report

## Current validation

The current pure Cangjie test suite contains 173 passing tests on Cangjie STS 1.1.3. Cangjie LTS 1.0.5 validation is executed by the dual-version CI matrix introduced during release preparation.

The repository does not currently claim a source-line coverage percentage because no retained `cjcov` report has yet been generated in CI. This document records functional coverage only; a generated HTML or machine-readable report must be added before a numerical coverage claim is made.

## Functional coverage matrix

| Area | Coverage |
|---|---|
| Unsigned Varint boundaries | Positive, boundary and malformed vectors |
| Signed ZigZag boundaries | Positive and boundary vectors |
| Bool and Option discriminants | Valid and invalid values |
| UTF-8 String and Rune | Valid, invalid and truncated input |
| Float32/Float64 | Binary round trips |
| UInt128/Int128 | Minimum, maximum and sample vectors |
| Sequence and map | Round trips, truncation and malicious declared lengths |
| Tuple, struct and enum forms | Declaration-order behavior and payload variants |
| Fixed and growable output | Success and capacity failures |
| Extend and stream IO | Read/write behavior and scratch storage |
| COBS | Golden frame, malformed frame, accumulator and remainder |
| CRC32C/iSCSI | Golden checksum, mismatch and remainder |
| Fixed-width integers | LE/BE 16/32/64/128-bit fields |
| Schema and stable keys | Formatting, serialization, recursive use and keys |
| Dynamic values | Lossless and JSON-compatible round trips |
| Legacy macros | Codec, Schema and MaxSize generation |
| NG macros | Schema and MaxSize generation |
| Generic macros | Single- and multi-parameter generic structs |
| Pure Cangjie policy | CI rejection of Rust/Cargo/toolchain artifacts |

## Reproduction

```bash
cjpm build -V
cjpm test -V
```

Run the commands once with the Cangjie LTS 1.0.5 environment active and once with the Cangjie STS 1.1.3 environment active.

## Completion criteria

Before center-repository publication:

1. Retain the LTS and STS CI logs.
2. Generate and retain a `cjcov` report when the supported toolchain and test layout are finalized.
3. Record uncovered public branches or explicit exclusions.
4. Do not report a numerical coverage percentage without the generated report artifact.

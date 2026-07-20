# LLT Coverage Report

## Current validation

The pure Cangjie suite contains **178 passing tests** on both:

- Cangjie LTS 1.0.5
- Cangjie STS 1.1.3

Both matrix jobs also pass the pure-source gate and `cjpm build -V`.

The repository does not claim a source-line coverage percentage because a retained `cjcov` report has not yet been generated. This document records functional coverage only; a generated report is required before publishing a numerical percentage.

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
| Tuple, struct and enum forms | Declaration-order behavior and all payload forms |
| Fixed and growable output | Success and capacity failures |
| Extend and stream IO | Read/write behavior and scratch storage |
| COBS | Golden frame, malformed frame, accumulator and remainder |
| CRC32C/iSCSI | Golden checksum, mismatch and remainder |
| Fixed-width integers | LE/BE 16/32/64/128-bit fields |
| Schema and stable keys | Formatting, serialization, recursive use and keys |
| Dynamic values | Lossless and JSON-compatible round trips |
| Legacy macros | Codec, Schema and MaxSize generation for structs/enums |
| NG macros | Schema and MaxSize generation for structs/enums |
| Generic macros | Single- and multi-parameter generic structs and enums |
| Security regression | Malicious collection lengths without direct wire-count allocation |
| Pure Cangjie policy | Rejection of Rust/Cargo/toolchain artifacts |
| Compiler compatibility | Full suite under LTS 1.0.5 and STS 1.1.3 |

## Reproduction

Activate one SDK environment and run:

```bash
cjpm build -V
cjpm test -V
```

Repeat with only the other SDK environment active.

## Completion criteria

Before center-repository publication:

1. Retain LTS and STS CI logs.
2. Generate and retain a `cjcov` report.
3. Record uncovered public branches or explicit exclusions.
4. Do not report a numerical source-line percentage without the generated artifact.

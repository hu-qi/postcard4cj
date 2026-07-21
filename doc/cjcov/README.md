# LLT Coverage Report

## Current validation

Latest quality run: GitHub Actions workflow `29798361619`, Cangjie STS 1.1.3.

- tests: **189 passed, 0 failed, 0 skipped, 0 errors**
- all instrumented files under `src`: **3854 / 5813 lines, 66.30%**
- runtime-library files excluding tests, benchmarks, and compile-time macro packages: **2106 / 2935 lines, 71.75%**
- reports generated: HTML details, XML, and JSON

The complete generated report is retained as the `postcard4cj-quality-artifacts` workflow artifact. It contains `index.html`, per-file HTML pages, `coverage.xml`, and `coverage.json`.

Compile-time macro packages are included in the all-source denominator but report zero runtime hits because Cangjie coverage instruments executed runtime code rather than macro-expansion execution. The second figure therefore isolates runtime-library coverage while keeping the all-source figure visible.

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
| COBS | Golden frame, malformed frame, 254-byte block, accumulator and remainder |
| CRC32C/iSCSI | Golden checksum, split writes, mismatch and remainder |
| Fixed-width integers | LE/BE 16/32/64/128-bit fields |
| Schema and stable keys | Formatting, serialization, recursive use and keys |
| Dynamic values | Lossless and JSON-compatible round trips |
| Legacy and NG macros | Codec, Schema and MaxSize structs/enums |
| Generic macros | Single/multi-parameter structs/enums and merged `where` bounds |
| Rename metadata | Legacy and NG type, field and variant names |
| Security regression | Malicious collection lengths without direct wire-count allocation |
| Pure Cangjie policy | Rust/Cargo/toolchain rejection |
| Compiler compatibility | Full suite under LTS 1.0.5 and STS 1.1.3 |

## Reproduction

```bash
cjpm test --coverage -V
mkdir -p target/cjcov
cjcov --root=. --source=src --html-details --xml --json --output=target/cjcov
```

Do not run `cjpm bundle` before copying the report out of `target`, because bundling may rebuild that directory. CI writes coverage reports to a runner-temporary directory and uploads them as artifacts.

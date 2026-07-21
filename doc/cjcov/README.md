# LLT Coverage Report

## Current validation

Latest quality run: GitHub Actions run `29810847543` (`postcard4cj pure Cangjie` run #200), Cangjie STS 1.1.3.

- tests: **189 passed, 0 failed, 0 skipped, 0 errors**
- all instrumented files under `src`: **3854 / 5813 lines, 66.30%**
- runtime-library files excluding tests, benchmarks, and compile-time macro packages: **2106 / 2935 lines, 71.75%**
- compile-time macro packages: **980 instrumented lines**, reported separately because runtime coverage does not observe macro-expansion execution
- reports generated: HTML details, XML, and JSON

The complete generated report is retained as the `postcard4cj-quality-artifacts` workflow artifact. It contains the raw `cov_output` tree, `index.html`, per-file HTML pages, `coverage.xml`, and `coverage.json`.

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
cjcov \
  --root="$(pwd)/cov_output" \
  --source="$(pwd)/src" \
  --html-details \
  --xml \
  --json \
  --output="$(pwd)/target/cjcov"
```

`cjpm test --coverage` collects the raw `.gcno` and `.gcda` files under `cov_output/<package>/`. Copy or generate the report before commands that clean or replace build artifacts. CI uploads both the raw coverage tree and the rendered reports.

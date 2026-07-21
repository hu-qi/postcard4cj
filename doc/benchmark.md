# Benchmark Report

## Environment

Latest benchmark run: GitHub Actions run `29810847543` (`postcard4cj pure Cangjie` run #200).

- Cangjie: STS 1.1.3
- runner: GitHub-hosted Ubuntu 22.04, x86_64
- package compile option: `-O2`
- framework: `std.unittest` native `@Bench`
- result: **6 passed, 0 failed**

The values below are useful as a CI baseline for regression detection. They are not cross-machine performance guarantees.

## Results

| Case | Median | Mean | Error |
|---|---:|---:|---:|
| Plain encode | 16.51 µs | 16.65 µs | ±0.5% |
| Plain decode | 3.432 µs | 3.501 µs | ±1.6% |
| COBS encode | 16.97 µs | 17.03 µs | ±0.5% |
| COBS decode | 4.162 µs | 4.186 µs | ±0.8% |
| CRC32C encode | 18.09 µs | 18.23 µs | ±0.4% |
| CRC32C decode | 4.855 µs | 4.860 µs | ±0.4% |

The benchmark payload exercises a representative compound Postcard value. COBS uses the incremental 254-byte segment implementation; CRC32C updates the checksum while forwarding payload bytes.

## Reproduction

```bash
source /path/to/cangjie/envsetup.sh
cjpm bench -V
```

The complete console report is retained as `postcard4cj-benchmark.log` in the `postcard4cj-quality-artifacts` workflow artifact.

## Interpretation

- Encode cases include output allocation and final byte materialization.
- Decode cases include validation and reconstruction of the benchmark value.
- Framing cases include COBS or CRC32C work in addition to the plain codec.
- Compare results only on equivalent compiler versions, optimization flags, payloads, and runner classes.

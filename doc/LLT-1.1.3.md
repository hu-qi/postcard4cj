# postcard4cj Cangjie 1.1.3 LLT 测试报告

## 测试结论

`feat/postcard4cj-1.1.3` 在 Cangjie STS 1.1.3 下通过完整质量矩阵。

| 检查项 | 结果 |
|---|---|
| `cjpm build` | 通过 |
| `cjpm test` | 189 通过，0 失败，0 跳过，0 错误 |
| `cjpm bench` | 6 通过，0 失败 |
| `cjpm bundle --skip-lint` | 通过 |
| 打包制品 | `target/postcard4cj-0.1.0.cjp` |

## 测试环境

- 测试日期：2026-07-29
- 分支：`feat/postcard4cj-1.1.3`
- 操作系统：macOS 26.5.2，Apple Silicon arm64
- 仓颉编译器：Cangjie Compiler 1.1.3（cjnative）
- 项目编译选项：`-O2`
- macOS SDK：Command Line Tools MacOSX15.4.sdk
- 部署目标：macOS 12.0

测试用例构成与 [1.0.5 完整 LLT 报告](LLT.md)相同，共覆盖 18 个测试包、189 项行为测试。

## 基准测试

| 用例 | 中位数 | 平均值 | 误差 |
|---|---:|---:|---:|
| Plain encode | 8.126 µs | 8.238 µs | ±2.6% |
| Plain decode | 1.534 µs | 1.542 µs | ±0.6% |
| COBS encode | 8.531 µs | 8.603 µs | ±1.4% |
| COBS decode | 1.942 µs | 1.935 µs | ±1.4% |
| CRC32C encode | 9.640 µs | 9.610 µs | ±0.8% |
| CRC32C decode | 2.657 µs | 2.643 µs | ±0.5% |

数值仅用于相同机器、编译器和参数下的回归比较。

## 本地复现

```bash
source /path/to/cangjie-1.1.3/envsetup.sh
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
export MACOSX_DEPLOYMENT_TARGET=12.0

# 此环境仅用于当前 macOS 上 cjpm bundle 的 SHA256/OpenSSL 运行依赖。
export DYLD_LIBRARY_PATH="/opt/homebrew/opt/openssl@3/lib:${DYLD_LIBRARY_PATH}"

cjc -v
cjpm clean
cjpm build
cjpm test
cjpm bench
cjpm bundle --skip-lint
```

测试宏展开产生的 `unreachable block` 和少量 `unused function` 为仓颉测试框架及派生宏的编译告警，不影响测试结果；本次没有屏蔽告警。

# 基准测试报告

## 环境

- 日期：2026-07-29
- 分支：`main`
- 仓颉版本：LTS 1.0.5
- 系统：macOS 26.5.2，Apple Silicon arm64
- 编译选项：`-O2`
- 框架：`std.unittest` 原生 `@Bench`
- 结果：**6 通过，0 失败**

以下结果适合作为同机回归基线，不代表跨机器性能保证。

## 结果

| 用例 | 中位数 | 平均值 | 误差 |
|---|---:|---:|---:|
| Plain encode | 7.037 µs | 7.292 µs | ±3.6% |
| Plain decode | 1.710 µs | 1.735 µs | ±2.7% |
| COBS encode | 7.662 µs | 7.719 µs | ±3.0% |
| COBS decode | 2.057 µs | 2.078 µs | ±1.2% |
| CRC32C encode | 8.457 µs | 8.702 µs | ±3.3% |
| CRC32C decode | 2.755 µs | 2.755 µs | ±0.7% |

benchmark payload 使用代表性的复合 Postcard 值。COBS 使用增量 254 字节分段实现；CRC32C 在转发 payload 字节时同步更新校验值。

## 复现

```bash
source /path/to/cangjie-1.0.5/envsetup.sh
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
export MACOSX_DEPLOYMENT_TARGET=12.0
cjpm bench -V
```

## 解读

- Encode 包含输出分配和最终字节数组构造。
- Decode 包含输入校验和 benchmark 值重建。
- Framing 在普通 codec 之外包含 COBS 或 CRC32C 工作。
- 只有编译器版本、优化参数、payload 和执行机器一致时才应直接比较结果。

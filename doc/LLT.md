# postcard4cj LLT 测试报告

## 1. 测试结论

postcard4cj 在 Cangjie LTS 1.0.5 下通过编译、单元测试、覆盖率采集和基准测试，可以作为 `main` 分支的 1.0.5 适配基线。

| 检查项 | 结果 |
|---|---|
| `cjpm build` | 通过 |
| `cjpm test --coverage -V` | 197 通过，0 失败，0 跳过，0 错误 |
| `cjcov` 报告 | HTML、XML、JSON 均生成成功 |
| 全部 `src` 行覆盖率 | 3974 / 5953，66.76% |
| 运行时代码行覆盖率 | 2163 / 3005，71.98% |
| `cjpm bench -V` | 6 通过，0 失败 |
| `cjpm bundle --skip-lint` | 1.0.5 的 `cjpm` 不提供 `bundle` 子命令；在 1.1.3 分支验证 |

## 2. 测试环境

- 测试日期：2026-07-29
- 分支：`main`
- 验证基线：`b7e9baa` 加本次文档及报告变更
- 操作系统：macOS 26.5.2，Apple Silicon arm64
- 仓颉编译器：Cangjie Compiler 1.0.5（cjnative）
- 项目编译选项：`-O2`
- macOS SDK：Command Line Tools MacOSX15.4.sdk
- 部署目标：macOS 12.0

## 3. 单元测试明细

| 测试包 | 通过数 |
|---|---:|
| `postcard4cj` | 40 |
| `postcard4cj.core` | 7 |
| `postcard4cj.max_size` | 7 |
| `postcard4cj.compatibility` | 8 |
| `postcard4cj.flavors` | 13 |
| `postcard4cj.serde_model` | 12 |
| `postcard4cj.accumulator` | 5 |
| `postcard4cj.fixint` | 6 |
| `postcard4cj.flavors_integration_test` | 2 |
| `postcard4cj.schema` | 12 |
| `postcard4cj.v2` | 10 |
| `postcard4cj.dynamic` | 19 |
| `postcard4cj.postcard_macro_test` | 25 |
| `postcard4cj.v2_eio` | 5 |
| `postcard4cj.v2_fixed` | 5 |
| `postcard4cj.derive_ng_test` | 15 |
| `postcard4cj.dynamic_ng` | 3 |
| `postcard4cj.io` | 3 |
| **合计** | **197** |

## 4. 功能覆盖矩阵

| 功能域 | 已验证内容 |
|---|---|
| Varint / ZigZag | 正常值、边界值、非法和截断输入 |
| 基础类型 | Bool、整数、128 位整数、Float、Rune、String、Option、Unit |
| 复合类型 | sequence、map、tuple、struct、exhaustive enum |
| 输出缓冲区 | 固定容量、可增长数组、Extend sink、容量不足 |
| 流式 IO | 读写、scratch storage、remainder |
| COBS | golden frame、非法帧、254 字节块、accumulator |
| CRC32 | iSCSI 与 ISO-HDLC golden checksum、可配置 digest、分段写入、校验失败 |
| Fixint | 16/32/64/128 位 LE/BE |
| Schema | 格式化、序列化、递归类型、稳定 key |
| enum-map | 固定数组 Schema、无长度前缀的 MaxSize 等价能力 |
| Dynamic | 无损值和 JSON 兼容转换 |
| 宏 | legacy/NG Codec、Schema、MaxSize、泛型及命名元数据 |
| 安全回归 | 恶意集合长度不会直接触发按 wire count 分配 |
| 上游兼容 | Rust Postcard 兼容向量 |
| 纯仓颉约束 | CI 拒绝 Rust/Cargo/toolchain 文件 |

## 5. 覆盖率说明

- [可浏览 HTML 报告](cjcov/index.html)
- [JSON 原始数据](cjcov/coverage.json)
- [Cobertura XML 数据](cjcov/coverage.xml)
- [覆盖率口径说明](cjcov/README.md)

全部 `src` 口径包含测试源码、benchmark 和编译期宏包。宏展开发生在编译期，运行时覆盖率无法观察宏执行，因此同时给出排除测试、benchmark、`postcard_macro` 和 `derive_ng` 后的运行时代码覆盖率。

项目使用 `-O2`，`cjpm test --coverage` 会提示覆盖率通常应关闭优化。为保持与项目实际发布配置一致，本报告保留该提示并使用同一配置采集；后续比较必须使用相同编译选项。

## 6. 基准测试

本机 1.0.5 结果如下。数值仅用于相同机器、编译器和参数下的回归比较。

| 用例 | 中位数 | 平均值 | 误差 |
|---|---:|---:|---:|
| Plain encode | 6.676 µs | 6.709 µs | ±0.6% |
| Plain decode | 1.627 µs | 1.638 µs | ±0.5% |
| COBS encode | 7.140 µs | 7.093 µs | ±0.5% |
| COBS decode | 2.011 µs | 1.993 µs | ±0.4% |
| CRC32C encode | 8.097 µs | 8.117 µs | ±0.8% |
| CRC32C decode | 2.677 µs | 2.685 µs | ±0.4% |

## 7. 本地复现

```bash
source /path/to/cangjie-1.0.5/envsetup.sh
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
export MACOSX_DEPLOYMENT_TARGET=12.0

cjc -v
cjpm clean
cjpm build
cjpm test --coverage -V
cjcov \
  --root="$(pwd)/cov_output" \
  --source="$(pwd)/src" \
  --html-details \
  --xml \
  --json \
  --output="$(pwd)/doc/cjcov"
cjpm bench -V
```

测试宏展开产生的 `unreachable block` 提示为仓颉测试框架及派生宏的已知编译告警，不影响测试结果；本次没有屏蔽告警。

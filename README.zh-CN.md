# postcard4cj

[English](README.md) | 简体中文

postcard4cj 是 [`jamesmunns/postcard`](https://github.com/jamesmunns/postcard) 工作区行为的**纯仓颉实现**，用于在仓颉项目中完成紧凑、确定性的二进制序列化与反序列化。

> **当前状态：Release Candidate。** 上游 11 个 workspace crate 均已有对应的仓颉包；仓库不包含 Rust 运行时实现；同一套源码已通过 Cangjie LTS 1.0.5 与 STS 1.1.3 的完整质量矩阵。

## 适合什么场景

- 网络协议、设备通信和消息队列中的紧凑二进制消息
- 需要确定性 wire bytes 的跨语言或跨端数据交换
- COBS、CRC32C/iSCSI 等带帧格式和校验的数据流
- 需要 Schema、Dynamic Value 或 Postcard2 风格 API 的仓颉项目
- 从 Rust Postcard 迁移到仓颉，且希望保持线格式兼容

## 支持版本

- LTS：Cangjie 1.0.5
- STS：Cangjie 1.1.3

默认 `main` 分支为 Cangjie 1.0.5 适配基线。Cangjie 1.1.3 适配维护在：

- `feat/postcard4cj-1.1.3`

## 安装

发布到仓颉中心仓后，可在项目的 `cjpm.toml` 中添加：

```toml
[dependencies]
postcard4cj = "0.1.0"
```

当前仓库已完成 `cjpm bundle` 验证；正式中心仓发布仍需维护者使用个人发布凭据执行。

## 五分钟上手

### 1. 定义可序列化类型

```cangjie
package demo

import postcard4cj.*
import postcard4cj.postcard_macro.*

@Postcard
public struct Message {
    public let id: UInt32
    public let enabled: Bool

    public init(id: UInt32, enabled: Bool) {
        this.id = id
        this.enabled = enabled
    }
}
```

### 2. 序列化和反序列化

```cangjie
let value = Message(42, true)
let bytes = toBytes<Message>(value)
let decoded = fromBytes<Message>(bytes)
```

`fromBytes` 是严格解码：如果消息后面还有多余字节，会返回对应错误。

处理连续消息流时，使用保留剩余数据的接口：

```cangjie
let result = takeFromByteArray<Message>(input)
let value = result[0]
let remainder = result[1]
```

### 3. COBS 帧

```cangjie
let frame = toBytesCobs<Message>(value)
let decoded = fromBytesCobs<Message>(frame)
let firstAndRemainder = takeFromBytesCobs<Message>(stream)
```

### 4. CRC32C/iSCSI 校验

```cangjie
let packet = toBytesCrc32Iscsi<Message>(value)
let decoded = fromBytesCrc32Iscsi<Message>(packet)
```

解码前会验证附加的 CRC32C 校验值。

## 主要能力

### Wire model

- 有符号、无符号 8/16/32/64/128 位整数
- 规范 Varint 与 ZigZag 编码
- Bool、Float32/64、Rune、UTF-8 String、字节数组、Option、Unit
- sequence、map、tuple、struct 与 exhaustive enum
- 严格解码和保留 remainder 的流式解码
- Postcard 1.x 的 16 类错误
- 针对不可信集合长度的分配保护

### Framing 与存储

- 固定缓冲区、可增长数组、Extend sink、流式读写
- 增量 COBS 构造，pending segment 最大 254 字节
- 增量 CRC32C 计算
- COBS accumulator
- 固定容量适配与 Postcard2 风格接口

### Schema 与 Dynamic

- 完整的运行时 Schema 模型
- Schema 格式化、递归类型发现、稳定 FNV key
- 无损 Dynamic Value
- JSON 兼容转换
- legacy 与 NG 两套命名空间

## 宏支持

- `@Postcard`
- `@PostcardSchema`
- `@PostcardMaxSize`
- `@PostcardSchemaNg`
- `@PostcardMaxSizeNg`
- `@PostcardSchemaNamed[...]`
- `@PostcardSchemaNgNamed[...]`

前五个入口支持：

- 普通 struct 与 exhaustive enum
- 单个或多个泛型参数
- 泛型 struct 与泛型 enum
- 将已有 `where` 上界与自动生成的 Postcard 上界合并

命名 Schema 宏可设置类型名、字段名和枚举变体名，仅影响 Schema 元数据，不改变 wire bytes：

```cangjie
@PostcardSchemaNamed["wire_record", "id=wire_id"]
public struct Record {
    public let id: UInt32
}
```

非 exhaustive enum 无法推导稳定的变体集合，因此会被拒绝。`PostcardMaxSize` 也会拒绝未提供边界的 String 和 Array 字段。

## 上游 workspace 对应关系

| Rust crate | 仓颉包 |
|---|---|
| `postcard-core` | `postcard4cj.core` |
| `postcard` | `postcard4cj` 以及 flavors、accumulator、fixint、IO、MaxSize |
| `postcard-derive` | `postcard4cj.postcard_macro` |
| `postcard-derive-ng` | `postcard4cj.derive_ng` |
| `postcard-schema` | `postcard4cj.schema` |
| `postcard-schema-ng` | `postcard4cj.schema_ng` |
| `postcard-dyn` | `postcard4cj.dynamic` |
| `postcard-dyn-ng` | `postcard4cj.dynamic_ng` |
| `postcard2` | `postcard4cj.v2` |
| `postcard2-eio` | `postcard4cj.v2_eio` |
| `postcard2-heapless` | `postcard4cj.v2_fixed` |

## 验证结果

当前完整 CI 结果：

- Cangjie 1.0.5：build 通过，**189 tests passed**
- Cangjie 1.1.3：build 通过，**189 tests passed**
- `cjcov` HTML/XML/JSON：生成成功
- 全部 instrumented `src` 行覆盖率：**66.30%**
- 排除测试、benchmark 和编译期宏包后的运行时代码覆盖率：**71.75%**
- 原生 benchmark：**6/6 passed**
- `cjpm bundle --skip-lint`：通过
- 制品：`postcard4cj-0.1.0.cjp`

## 中文文档

- [快速上手](doc/quickstart.zh-CN.md)
- [功能与 API 指南](doc/feature_api.zh-CN.md)
- [从 Rust Postcard 迁移](doc/migration.zh-CN.md)

## 英文文档

- [Design](doc/design.md)
- [Feature and API guide](doc/feature_api.md)
- [Coverage report](doc/cjcov/README.md)
- [Benchmarks](doc/benchmark.md)
- [Optional integration decisions](doc/optional_integrations.md)
- [Migration matrix](MIGRATION.md)
- [Public API compatibility](API_COMPATIBILITY.md)
- [Changelog](CHANGELOG.md)
- [Open-source record](README.OpenSource)
- [Test layout](test/README.md)

## 纯仓颉约束

CI 会在编译前拒绝以下内容：

- `.rs` 源码
- `Cargo.toml`、`Cargo.lock`
- Rust toolchain 配置
- `.cargo` 目录

序列化、反序列化、测试、兼容性向量、benchmark、覆盖率和打包均只使用仓颉工具链。

## License

本项目采用双许可证：

- Apache License 2.0
- MIT License

`NOTICE` 记录上游归属和本项目为独立仓颉实现的说明。

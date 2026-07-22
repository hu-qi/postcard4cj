# 从 Rust Postcard 迁移到 postcard4cj

本文说明如何将使用 Rust [`postcard`](https://github.com/jamesmunns/postcard) 的协议或应用迁移到仓颉 postcard4cj。

行为基线：

```text
jamesmunns/postcard@de182557cff45f2ca9b2b67a6b93be5917612a44
```

postcard4cj 是独立的纯仓颉实现。上游仓库仅用于定义协议行为与可观察语义，不参与 postcard4cj 的编译、测试或运行。

## 1. 首先判断迁移目标

迁移通常分为三种情况：

1. **只要求 wire bytes 兼容**：Rust 与仓颉端交换同一协议数据；
2. **要求 API 概念对应**：希望把 Rust Postcard 的调用方式迁移为仓颉等价接口；
3. **迁移完整 workspace 能力**：还需要 Schema、Dynamic、COBS、CRC、IO、Postcard2 等模块。

postcard4cj 已覆盖上游 11 个 workspace crate 的核心行为，但部分 Rust 语言机制会采用仓颉原生替代方案。

## 2. Workspace 对应关系

| Rust crate | postcard4cj 包 | 状态 |
|---|---|---|
| `postcard-core` | `postcard4cj.core` | 已实现 |
| `postcard` | `postcard4cj` 及工具包 | 已实现 |
| `postcard-derive` | `postcard4cj.postcard_macro` | 已实现 |
| `postcard-derive-ng` | `postcard4cj.derive_ng` | 已实现 |
| `postcard-schema` | `postcard4cj.schema` | 已实现 |
| `postcard-schema-ng` | `postcard4cj.schema_ng` | 已实现 |
| `postcard-dyn` | `postcard4cj.dynamic` | 已实现 |
| `postcard-dyn-ng` | `postcard4cj.dynamic_ng` | 已实现 |
| `postcard2` | `postcard4cj.v2` | 已实现 |
| `postcard2-eio` | `postcard4cj.v2_eio` | 使用仓颉 IO 接口实现 |
| `postcard2-heapless` | `postcard4cj.v2_fixed` | 使用运行时容量实现 |

## 3. 常用 API 映射

### 3.1 序列化

| Rust Postcard | postcard4cj |
|---|---|
| `to_allocvec` / owned vec output | `toBytes<T>` / `toByteArray<T>` |
| `to_slice` | `toSlice` / `encodeTo` |
| Extend output | `ExtendSerializeFlavor` / `toExtendV2` |
| `to_io` / embedded IO | `postcard4cj.io.toIo` / `toEioV2` |
| `to_allocvec_cobs` 等 COBS API | `toBytesCobs<T>` / `encodeToCobs` |
| CRC Flavor | `toBytesCrc32Iscsi<T>` / `encodeToCrc32Iscsi` |
| `serialized_size` | `serializedSize` / `serializedSizeV2` |

### 3.2 反序列化

| Rust Postcard | postcard4cj |
|---|---|
| `from_bytes` | `fromBytes<T>` / `fromByteArray<T>` |
| `take_from_bytes` | `takeFromByteArray<T>` |
| COBS decode | `fromBytesCobs<T>` |
| COBS take/remainder | `takeFromBytesCobs<T>` |
| CRC decode | `fromBytesCrc32Iscsi<T>` |
| CRC take/remainder | `takeFromBytesCrc32Iscsi<T>` |
| IO input | `postcard4cj.io.fromIo` / `fromEioV2` |

## 4. Derive 迁移为仓颉宏

Rust 中常见的 Serde derive：

```rust
#[derive(Serialize, Deserialize)]
struct Message {
    id: u32,
    enabled: bool,
}
```

在仓颉中使用：

```cangjie
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

对应的 Schema 与 MaxSize 宏：

- `@PostcardSchema`
- `@PostcardMaxSize`
- `@PostcardSchemaNg`
- `@PostcardMaxSizeNg`

泛型 struct 和 exhaustive enum 支持一个或多个类型参数。已有 `where` 上界会与宏生成的 Postcard 上界合并。

## 5. Wire format 保持不变的部分

下列协议规则保持与 Postcard 基线一致：

- 无符号 Varint
- 有符号 ZigZag
- Bool、Option discriminant
- 长度前缀
- struct 字段声明顺序
- enum variant 声明顺序
- tuple、sequence、map 的元素顺序
- 8/16/32/64/128 位整数语义
- COBS framing
- CRC32C/iSCSI framing
- exact decode 与 remainder decode 行为

只要两端使用相同类型结构和声明顺序，Rust 与仓颉端可生成一致的 wire bytes。

## 6. 必须理解的语言级替代

### 6.1 Borrowed data → Owned data

Rust Postcard 可以依赖生命周期表达借用反序列化；仓颉实现使用拥有所有权的：

- `String`
- `Array<UInt8>`
- 调用方提供的 scratch array

这不会改变 wire bytes，但会改变内存所有权与 API 形态。

### 6.2 Rust `Result` → 仓颉异常

postcard4cj 使用仓颉异常暴露失败，同时保留明确错误类别，例如：

- unexpected end
- trailing bytes
- invalid Bool / Option / UTF-8 / Rune / Varint
- unknown enum variant
- output capacity exhaustion
- malformed COBS
- CRC mismatch

迁移业务代码时，需要将 Rust 的 `match Result` 改为仓颉异常处理。

### 6.3 Const generic capacity → Runtime capacity

Rust `heapless::Vec<u8, N>` 的编译期容量，在 postcard4cj 中由运行时容量的 `FixedByteVec` / fixed Flavor 替代。

容量溢出仍会确定性失败，但容量不再由 Rust const generic 类型参数表达。

### 6.4 embedded-io traits → ByteReader / ByteWriter

Rust 的版本化 embedded-IO trait 被仓颉原生：

- `ByteReader`
- `ByteWriter`

替代。

### 6.5 Static/owned Schema tree → 单一运行时 Schema graph

postcard4cj 使用一套 runtime-owned Schema graph，替代 Rust 中静态引用与 owned tree 的双模型。

## 7. Enum 兼容性注意事项

枚举索引取决于变体声明顺序。

已发布协议中：

- 不要交换已有变体的位置；
- 不要在中间插入新变体；
- 不要把 exhaustive enum 改为不稳定的变体集合；
- Rust 与仓颉端必须保持相同 payload 形态。

postcard4cj 宏会拒绝 non-exhaustive enum，因为无法为其推导稳定的 wire variant set。

## 8. Schema rename 与 wire bytes

命名 Schema 宏：

- `@PostcardSchemaNamed[...]`
- `@PostcardSchemaNgNamed[...]`

可设置类型名、字段名和 enum variant 名。

这些 rename 仅影响 Schema 元数据，不会改变 wire bytes。因此它们不能替代真正的协议字段顺序或类型变更。

## 9. MaxSize 迁移

Rust 侧如果依赖编译期最大尺寸，仓颉端可使用 `PostcardMaxSize`。

注意：

- 固定大小 primitive、tuple、bounded struct 可计算；
- 未提供边界的 String 与 Array 无法计算；
- 对无界字段，应使用 bounded wrapper 或手动实现。

## 10. COBS 与 CRC 性能差异

当前 postcard4cj 已完成低分配优化：

- COBS 增量构造，最多保留 254 字节 pending segment；
- CRC32C 边写边计算；
- finalize 阶段不复制第二份完整消息；
- 保留 Flavor `snapshot()` 的非破坏语义。

这些实现差异不影响 wire bytes。

## 11. 不可信输入与分配安全

Rust 和仓颉端都不能把 wire 中的集合长度当成可信数据。

postcard4cj 已避免 sequence/map 的恶意声明长度直接触发对应规模的预分配，但迁移后仍建议：

- 限制消息总大小；
- 限制集合数量；
- 对业务字段进行二次校验；
- 单消息使用 strict decode；
- 流数据才使用 take-style API。

## 12. 可选生态类型

上游部分 feature 依赖 Rust 生态类型，不能通过嵌入 Rust 代码直接移植，例如：

- UUID
- 日期时间
- 矩阵与向量
- 定点数
- 诊断格式化
- 大型定长数组 helper
- 历史 heapless / embedded-IO alias

迁移时应采用以下策略之一：

1. 使用仓颉原生类型并手动实现 codec；
2. 在应用层转换为已支持的 primitive/struct；
3. 明确记录为不支持，而不是伪装为完全兼容。

## 13. 推荐迁移步骤

1. 固定 Rust 端 Postcard 版本和协议结构；
2. 为关键类型生成 Golden Vector；
3. 在仓颉中建立等价 struct/enum；
4. 使用 `@Postcard` 或手动 codec；
5. 对比编码后的字节数组；
6. 验证 malformed、truncated、trailing input；
7. 验证 COBS/CRC 和 remainder；
8. 验证集合长度与容量边界；
9. 再迁移 Schema、Dynamic、IO 等高级模块；
10. 将跨语言 Golden Vector 固化为回归测试。

## 14. 当前验证结果

同一套 postcard4cj 源码已在以下编译器上通过：

- Cangjie 1.0.5：189 tests passed
- Cangjie 1.1.3：189 tests passed

测试覆盖 primitive、compound、128 位整数、enum 顺序、COBS、CRC32C、remainder、malformed input、恶意长度、Flavor、宏、泛型、where 合并与 Schema rename。

## 15. 相关文档

- [中文快速上手](quickstart.zh-CN.md)
- [中文功能与 API 指南](feature_api.zh-CN.md)
- [完整英文迁移矩阵](../MIGRATION.md)
- [公共 API 兼容性审计](../API_COMPATIBILITY.md)
- [可选生态集成决策](optional_integrations.md)

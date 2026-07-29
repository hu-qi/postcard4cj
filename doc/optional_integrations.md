# 可选生态集成决策

简体中文 | [English](optional_integrations.en.md)

上游 Postcard workspace 提供若干 Rust 生态类型的可选集成。postcard4cj 是纯仓颉库，不会为了复刻 feature 名称而嵌入 Rust crate。本文记录每类上游集成的发布决策。

## 通用适配器约定

仓颉应用类型可以通过实现以下接口参与 Postcard 编解码：

- `PostcardEncode`
- `PostcardDecode<T>`
- 可选的 `PostcardSchema<T>` 或 `PostcardSchemaNg<T>`
- 类型存在有限编码上界时，可选实现 `PostcardMaxSize`

适配器必须保持逻辑值的 Postcard 线格式表示。适配器由拥有或选择相应仓颉原生类型的包维护，从而避免 postcard4cj 依赖无关生态库。

## 决策

| 上游集成 | 仓颉决策 | 状态 |
|---|---|---|
| UUID | 通过应用适配器编码规范的 16 字节值；postcard4cj 不指定某个第三方 UUID 包。 | 公共适配器接口支持；无内置依赖 |
| chrono/date-time | 编码明确选定的数值或结构化时间表示；时区和日历语义由应用类型负责。 | 公共适配器接口支持；无内置依赖 |
| nalgebra matrix/vector | 通过 sequence/tuple API 编码维度和标量元素；postcard4cj 不指定矩阵包。 | 公共适配器接口支持；无内置依赖 |
| 定点数 | 根据选定的 scale 约定编码底层有符号/无符号整数。 | 公共适配器接口支持；无内置依赖 |
| defmt diagnostics | 诊断格式不属于线格式，使用仓颉异常和普通格式化。 | 明确排除的 Rust 专属诊断集成 |
| serde-big-array | 仓颉 `Array<T>` 和显式固定容量包装使用普通 sequence/fixed API，不需要 serde workaround。 | 原生核心 API；无需独立集成 |
| enum-map 3.x | 使用 `enumMapSchema(valueSchema, enumCardinality)` 和 `enumMapMaxSize<V>(enumCardinality)` 表达枚举键对应的固定值数组；与上游一样不编码长度前缀。 | 已实现仓颉原生等价能力 |
| heapless 0.7/0.8/0.9 alias | `FixedByteVec` 和 `FixedVecFlavor` 提供运行时容量替代，不导入带版本的 Rust 容器。 | 已实现的仓颉替代 |
| embedded-io 0.4/0.6 alias | `ByteReader` 和 `ByteWriter` 提供稳定仓颉 IO 约定，不依赖带版本的 Rust trait。 | 已实现的仓颉替代 |

## 兼容性边界

这些决策声明的是线格式能力，不是与 Rust 类型名的源码级兼容。原生适配器必须记录所选逻辑表示；需要与其他实现互操作时，还必须包含 Golden Vector 测试。

任何可选集成都不能向 postcard4cj 添加 `.rs`、Cargo、Rust 工具链或 Rust 运行时依赖。

# postcard4cj 设计说明

简体中文 | [English](design.en.md)

## 1. 目标

postcard4cj 是 Postcard 二进制线格式及其上游 workspace 可观察行为的纯仓颉实现。

设计目标：

1. 保持 Postcard 线格式兼容。
2. 提供仓颉原生 API，不包装或执行 Rust 代码。
3. 使用同一套源码支持 Cangjie LTS 1.0.5 和 STS 1.1.3。
4. 覆盖固定缓冲区、可增长存储、流式 IO、COBS、CRC32C、Schema、Dynamic 和宏等场景。
5. 确定性拒绝非法或恶意输入，不按不可信长度提前分配。
6. 记录所有有意采用的语言层替代设计。

上游行为基线：

```text
jamesmunns/postcard@118d274cf46ee8097e7a4aae0c12a801c7aea8cc
```

## 2. 非目标

- 嵌入或编译上游 Rust 实现。
- 直接暴露 Rust 生命周期、所有权、const generic 或 `Result` 类型。
- 在仓颉原生实现和测试完成前宣称支持可选生态集成。
- 把实现方式相似当作兼容性证据；兼容性必须由固定仓颉向量验证。

## 3. 架构

| 层级 | 包 | 职责 |
|---|---|---|
| 线格式核心 | `postcard4cj.core` | Varint、ZigZag、长度、判别值、基础项、位置和错误 |
| 公共 codec | `postcard4cj` | Encoder/decoder、codec 接口和便捷函数 |
| 结构化模型 | `postcard4cj.serde_model` | sequence、map、tuple、struct 和 enum 操作 |
| Flavor | `postcard4cj.flavors` | 固定、可增长、Extend、stream、size、COBS 和 CRC 组合 |
| 工具 | accumulator、fixint、IO、MaxSize 包 | 分帧、定宽值、流和大小上界 |
| Schema | legacy 和 NG Schema 包 | 运行时所有的图、格式化、遍历和稳定 key |
| Dynamic | legacy 和 NG Dynamic 包 | Schema 驱动的无损值和 JSON 兼容转换 |
| 现代门面 | v2、v2_eio 和 v2_fixed 包 | Postcard2 风格 API 和仓颉存储/IO 适配 |
| 宏 | `postcard_macro`、`derive_ng` | 生成 Codec、Schema 和 MaxSize |
| 测试 | compatibility 和 `*_test` 包 | Golden Vector、非法输入和回归验证 |

## 4. 线格式不变量

- 无符号整数使用规范变长编码。
- 有符号整数先做 ZigZag，再做变长编码。
- Bool 和 Option 判别值只接受协议规定的值。
- String、字节、sequence 和 map 长度使用 Postcard 长度编码。
- struct 字段和 enum 变体按声明顺序编码。
- 浮点值保留其二进制 payload。
- 严格解码拒绝尾随字节。
- take 风格解码返回未使用字节。
- COBS 帧以零结尾。
- CRC 分帧使用 CRC32C/iSCSI，并验证附加校验和。

任何影响线格式的修改都必须增加固定兼容性向量。

## 5. 仓颉替代设计

### 所有权

使用有所有权的 `String` 和 `Array<UInt8>` 替代受生命周期约束的借用字符串和字节切片。需要临时存储时，由调用方提供 scratch 数组。

### 错误

使用仓颉异常替代通用 Rust `Result`，同时保留协议、容量、分帧和不支持操作等明确错误类别。

### 容量

使用运行时容量的固定向量替代 const-generic 存储。容量不足是确定且可观察的失败。

### IO

使用仓颉 `ByteReader` 和 `ByteWriter` 替代 embedded-io trait。流式 API 与数组 API 产生相同的线格式字节。

### Schema

使用一套运行时所有的 Schema 图替代静态引用树和 owned tree。格式化、递归遍历和稳定 key 仍是可观察且经过测试的行为。

## 6. Flavor 组合

1. Encoder 产生规范 Postcard 字节。
2. 存储 Flavor 选择固定缓冲区、可增长数组、Extend sink、stream writer 或 size counter。
3. COBS 和 CRC32C Flavor 应用分帧。
4. 最终化返回所选输出。

反序列化 Flavor 提供 slice、stream、已解码 COBS 和已验证 CRC 数据源。支持 remainder 的函数保留当前消息未消费的字节。

COBS 输出以增量方式构造，pending segment 最大为 254 字节。字节流经 Flavor 时同步更新 CRC32C。最终化不会再次复制完整消息，`snapshot()` 不修改状态，并保持嵌套 middleware 顺序。

## 7. 宏设计

五个 codec/Schema/MaxSize 宏入口解析声明并生成接口扩展：

- `@Postcard`
- `@PostcardSchema`
- `@PostcardMaxSize`
- `@PostcardSchemaNg`
- `@PostcardMaxSizeNg`

支持的声明边界：

- 非泛型 struct
- exhaustive 非泛型 enum
- 包含一个或多个类型参数的泛型 struct
- 包含一个或多个类型参数的 exhaustive 泛型 enum
- 带或不带既有 `where` 上界的声明
- primitive、nested、`Option<T>` 和 `Array<T>` codec/Schema 字段
- 有界 MaxSize payload 类型

生成器从标识符 token 重建泛型参数列表和约束。既有上界从 AST 读取，并与生成的 codec、Schema 或 MaxSize 要求合并，不重复声明类型参数。

命名 Schema 宏提供类型、字段和 enum 变体的重命名元数据：

- `@PostcardSchemaNamed[...]`
- `@PostcardSchemaNgNamed[...]`

重命名只改变 Schema 名称，不改变线格式字节。

明确不支持：

- 为 non-exhaustive enum 生成实现
- 无边界 String/Array 字段的 MaxSize

不支持的声明必须产生明确编译期诊断，不能生成无效代码。

## 8. 安全和资源限制

线格式中的长度不可信。

- sequence 和 map decoder 不直接按声明的 wire count 预分配。
- 初始分配量受剩余输入长度限制。
- 输入截断时，在返回完整值前失败。
- 非法 UTF-8、Rune、判别值、varint、COBS 和 CRC 输入产生已定义错误。
- 固定容量输出在超过配置容量时失败。

每个新增的带长度前缀 decoder 都必须包含恶意长度回归测试。

## 9. 验证

兼容性完全使用仓颉验证。测试覆盖：

- 基础类型边界及非法值
- record 和 compound value
- enum 声明顺序
- 128 位有符号和无符号整数
- COBS、CRC32C 帧和 remainder 行为
- 固定、可增长、Extend 和流式路径
- Schema、Dynamic 和 JSON 兼容行为
- 生成的 struct 和 enum
- 单参数和多参数泛型 struct/enum
- 既有 `where` 上界合并
- Schema 重命名元数据
- 恶意集合长度

CI 在 Cangjie 1.0.5 和 1.1.3 下运行：

```bash
cjpm build -V
cjpm test -V
```

两个版本的最新结果均为：**197 通过，0 失败，0 跳过，0 错误**。

STS 质量任务还会生成覆盖率报告、运行原生 benchmark、检查 lint 错误并验证发布 bundle。

## 10. 发布模型

项目遵循 cj-awesome 双版本模型：

- `main` 是 Cangjie 1.0.5 适配基线。
- `feat/postcard4cj-1.1.3` 承载 Cangjie 1.1.3 适配。
- 发布制品必须标明支持的编译器版本线。
- 两个编译器接受相同源码时共享实现逻辑。

## 11. 变更要求

行为变更只有满足以下条件才算完成：

1. 源码保持纯仓颉。
2. LTS 和 STS 均能构建并通过测试，或版本差异已隔离并记录。
3. 包含正向测试及相关负向测试。
4. 线格式变更包含 Golden Vector。
5. 公共 API 变更同步更新 `doc/feature_api.md`、`doc/feature_api.en.md` 和 `API_COMPATIBILITY.md`。
6. 用户可见变更更新 `CHANGELOG.md`。
7. 新的所有权、容量或 IO 替代设计已记录。
8. 中文入口文档与英文对照文档保持一致。

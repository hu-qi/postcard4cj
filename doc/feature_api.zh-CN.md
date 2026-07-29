# postcard4cj 功能与 API 指南

## 1. 包与编译器支持

```toml
[dependencies]
postcard4cj = "0.1.0"
```

当前源码支持：

- Cangjie LTS 1.0.5
- Cangjie STS 1.1.3

项目已达到 release candidate 状态并通过 bundle 验证。中心仓安装是否可用取决于维护者是否已经完成正式发布。

## 2. 核心接口

用户自定义类型通过以下接口接入 codec：

```cangjie
public interface PostcardEncode {
    func encode(encoder: PostcardEncoder): Unit
}

public interface PostcardDecode<T> {
    static func decode(decoder: PostcardDecoder): T
}
```

手动实现时，编码和解码必须使用相同的字段顺序与数据类型。

## 3. 基础序列化

```cangjie
let bytes = toBytes<MyType>(value)
let decoded = fromBytes<MyType>(bytes)
```

严格解码会拒绝尾随字节。

处理连续消息并保留未消费数据：

```cangjie
let result = takeFromByteArray<MyType>(input)
let value = result[0]
let remainder = result[1]
```

## 4. 支持的数据类型

- Bool
- 有符号和无符号 8/16/32/64/128 位整数
- Float32、Float64
- Rune、Unit
- UTF-8 String、字节数组
- Option
- sequence、map
- tuple、struct
- unit、newtype、tuple、struct enum variant

除非显式使用定宽包装，否则整数遵循 Postcard Varint 和 ZigZag 编码。

## 5. COBS framing

```cangjie
let frame = toBytesCobs<MyType>(value)
let value = fromBytesCobs<MyType>(frame)
let result = takeFromBytesCobs<MyType>(stream)
```

Take-style 接口会解码第一个以零字节分隔的完整帧，并返回后续全部字节。

序列化端使用增量 COBS block 构造，最多缓存 254 字节 pending segment。

## 6. CRC32C/iSCSI framing

```cangjie
let message = toBytesCrc32Iscsi<MyType>(value)
let value = fromBytesCrc32Iscsi<MyType>(message)
let result = takeFromBytesCrc32Iscsi<MyType>(stream)
```

解码器在返回值前验证附加的 CRC32C 校验值。序列化过程边写边更新 checksum，不在 finalize 阶段复制第二份完整消息。

## 7. Flavors

序列化 Flavor 支持：

- 调用方提供的固定缓冲区
- 可增长数组
- Extend sink
- stream writer
- 序列化尺寸计数器
- COBS middleware
- CRC32C middleware

反序列化 Flavor 支持：

- 带 remainder 的 slice
- 使用 scratch storage 的 stream reader
- 已解码的 COBS frame
- 通过 CRC32C 验证的消息

普通字节数组场景优先使用便捷函数；需要显式控制存储、容量或 framing 组合时使用 Flavor。

`Flavor.snapshot()` 保持非破坏语义，COBS 与 CRC middleware 可按声明顺序组合。

## 8. 定宽整数

`postcard4cj.fixint` 为 16/32/64/128 位整数提供 little-endian 与 big-endian codec。

只有当外围协议要求固定字段宽度时才使用定宽 helper；普通 Postcard 数据应继续使用默认 Varint 编码。

## 9. IO 与 Accumulator

`postcard4cj.io` 和 `postcard4cj.v2_eio` 使用仓颉原生 `ByteReader` 与 `ByteWriter` 接口。

`CobsAccumulator` 可持续接收任意大小的数据块，并在获得完整 COBS frame 时输出结果。其运行时容量会被确定性地执行。

## 10. Schema

`postcard4cj.schema` 提供：

- primitive、sequence、tuple、map、struct、enum Schema node
- Schema 格式化
- 递归 used-type discovery
- 稳定 type/path key
- Schema 本身的 Postcard 序列化

类型通过以下接口提供 Schema：

```cangjie
public interface PostcardSchema<T> {
    static func schema(): NamedType
}
```

NG 命名空间对应 `PostcardSchemaNg<T>` 与 `schemaNg()`。

## 11. Dynamic Value

`postcard4cj.dynamic` 提供由 Schema 驱动的无损运行时值，覆盖：

- primitive
- collection
- struct
- enum variant
- 任意 key 的 map
- Schema value
- 明确区分的 `None` 与 `Some(Unit)`

当 JSON 能保持数据语义时，可使用 JSON 兼容转换；当 JSON 会抹去类型差异时，应使用无损 Dynamic 模型。

## 12. 宏

### 12.1 Codec struct

```cangjie
@Postcard
public struct Message {
    public let id: UInt32
    public let name: String

    public init(id: UInt32, name: String) {
        this.id = id
        this.name = name
    }
}
```

### 12.2 Codec enum

```cangjie
@Postcard
public enum Command {
    | Ping
    | SetSpeed(UInt16)
    | Rename(String, Bool)
}
```

### 12.3 泛型 struct

```cangjie
@Postcard
public struct Pair<T, U> {
    public let first: T
    public let second: U

    public init(first: T, second: U) {
        this.first = first
        this.second = second
    }
}
```

### 12.4 泛型 enum

```cangjie
@Postcard
public enum ResultValue<T, U> {
    | Empty
    | Value(T)
    | Pair(T, U)
}
```

宏会为每个类型参数生成所需的 codec、Schema 或 MaxSize 上界。

### 12.5 已有 where 上界

泛型声明可以已有 `where` 约束。宏使用 AST 读取现有约束，并与自动生成的 Postcard 上界合并，不重复声明泛型参数。

### 12.6 Schema 与最大尺寸

```cangjie
@PostcardSchema
public struct SchemaMessage { /* fields and init */ }

@PostcardMaxSize
public struct BoundedMessage { /* bounded fields and init */ }
```

NG 入口：

- `@PostcardSchemaNg`
- `@PostcardMaxSizeNg`

五个 codec/Schema/MaxSize 入口均支持：

- 非泛型 struct
- 非泛型 exhaustive enum
- 单参数和多参数泛型 struct
- 单参数和多参数泛型 exhaustive enum
- 已有 `where` 上界合并

### 12.7 Schema rename

命名 Schema 宏提供仓颉原生的类型、字段与枚举变体 rename：

```cangjie
@PostcardSchemaNamed["wire_record", "id=wire_id"]
public struct Record {
    public let id: UInt32
}
```

NG 对应入口为 `@PostcardSchemaNgNamed[...]`。

Rename 只改变 Schema 元数据，不改变编码后的 wire bytes。

### 12.8 明确限制

- 非 exhaustive enum：拒绝生成，因为无法推导稳定变体集合；
- MaxSize 中无界 String/Array：拒绝生成，因为无法静态计算最大尺寸；
- 不支持的声明会给出编译期诊断。

## 13. 尺寸 API

- `serializedSize`：计算某个具体值的编码尺寸；
- `PostcardMaxSize`：描述有界类型的最大未加 Flavor 尺寸；
- 对无界字段，应提供有界包装或手动实现。

## 14. Postcard2 风格 API

`postcard4cj.v2` 提供：

- fixed output
- growable output
- Extend output
- serialized-size calculation
- strict decode
- remainder decode
- 独立错误类别

`postcard4cj.v2_eio` 与 `postcard4cj.v2_fixed` 分别提供 IO 和运行时容量 fixed-vector 适配。

## 15. 错误处理

错误通过仓颉异常暴露，并保留明确类别，包括：

- 输入意外结束
- 尾随字节
- 非法 Bool、Option、UTF-8、Rune、Varint
- 未知 enum variant
- 输出容量不足
- malformed COBS
- CRC mismatch
- unsupported operation

处理不可信外部数据时，应捕获与业务相关的异常，并在校验失败后停止处理消息。

## 16. 安全指导

- 将所有输入长度视为不可信；
- 根据业务需要增加集合数量和消息总大小限制；
- 单消息缓冲区使用严格解码；
- 只有明确处理消息流时才使用 take-style API；
- 在执行业务逻辑前完成 framing 验证；
- 不要静默忽略 malformed-input 错误。

postcard4cj 对 sequence/map 的恶意声明长度实施分配保护，不会直接按 wire count 进行大容量预分配。

## 17. 模块选择

| 模块 | 用途 |
|---|---|
| `postcard4cj` | 主要便捷 API 与核心 codec |
| `postcard4cj.core` | 底层 wire encoder/decoder |
| `postcard4cj.flavors` | 存储与 framing 组合 |
| `postcard4cj.accumulator` | 增量 COBS 数据流 |
| `postcard4cj.fixint` | 定宽整数 |
| `postcard4cj.io` | 仓颉原生流式 IO |
| `postcard4cj.max_size` | 最大尺寸模型 |
| `postcard4cj.schema` | legacy Schema |
| `postcard4cj.schema_ng` | NG Schema |
| `postcard4cj.dynamic` | legacy Dynamic |
| `postcard4cj.dynamic_ng` | NG Dynamic |
| `postcard4cj.v2` | Postcard2 风格 facade |
| `postcard4cj.v2_eio` | Postcard2 IO 适配 |
| `postcard4cj.v2_fixed` | 运行时 fixed-capacity 适配 |

## 18. 验证状态

同一套源码在 Cangjie 1.0.5 与 1.1.3 上均通过：

- build：通过
- tests：**189 passed, 0 failed, 0 skipped, 0 errors**

STS 质量任务还验证：

- `cjcov` HTML/XML/JSON 生成
- 全部 instrumented `src` 行覆盖率 66.28%
- 运行时代码覆盖率 71.75%
- benchmark 6/6 通过
- `cjpm bundle --skip-lint` 通过

## 19. 延伸阅读

- [中文快速上手](quickstart.zh-CN.md)
- [从 Rust Postcard 迁移](migration.zh-CN.md)
- [英文架构设计](design.md)
- [覆盖率报告](cjcov/README.md)
- [Benchmark](benchmark.md)
- [可选生态集成决策](optional_integrations.md)
- [完整迁移矩阵](../MIGRATION.md)
- [公共 API 兼容性](../API_COMPATIBILITY.md)
- [Changelog](../CHANGELOG.md)

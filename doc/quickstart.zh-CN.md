# postcard4cj 中文快速上手

本文面向第一次在仓颉项目中使用 postcard4cj 的开发者。完整能力和边界请参阅[功能与 API 指南](feature_api.zh-CN.md)。

## 1. 环境要求

- Cangjie LTS 1.0.5，或
- Cangjie STS 1.1.3

postcard4cj 的最低编译器版本声明为 1.0.5，同一套源码会在 LTS 与 STS 两条版本线上验证。

## 2. 添加依赖

正式发布到仓颉中心仓后，在项目的 `cjpm.toml` 中添加：

```toml
[dependencies]
postcard4cj = "0.1.0"
```

仓库源码当前已通过 `cjpm bundle --skip-lint`，但实际从中心仓安装取决于维护者是否已经完成 `cjpm publish`。

## 3. 定义消息类型

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

`@Postcard` 会为 struct 或 exhaustive enum 生成 `PostcardEncode` 和 `PostcardDecode<T>` 实现。

字段的声明顺序就是 wire format 的写入顺序。发送端和接收端必须使用一致的字段和变体顺序。

## 4. 编码与严格解码

```cangjie
let source = Message(42, true)
let bytes = toBytes<Message>(source)
let decoded = fromBytes<Message>(bytes)
```

`fromBytes` / `fromByteArray` 使用严格解码：

- 消息完整时返回结果；
- 输入截断时抛出对应异常；
- 消息后存在多余字节时拒绝解码。

这种模式适合一个缓冲区只包含一条完整消息的场景。

## 5. 解码连续消息流

处理 TCP 缓冲区、串口数据或拼接消息时，使用保留剩余字节的接口：

```cangjie
let result = takeFromByteArray<Message>(input)
let value = result[0]
let remainder = result[1]
```

调用方负责继续保存或处理 `remainder`。只有确实在处理连续消息流时才应使用 take-style API。

## 6. COBS 帧

COBS 适合使用 `0x00` 作为帧分隔符的串行通信场景。

```cangjie
let frame = toBytesCobs<Message>(source)
let decoded = fromBytesCobs<Message>(frame)
```

处理包含多帧的数据流：

```cangjie
let result = takeFromBytesCobs<Message>(stream)
let value = result[0]
let remainder = result[1]
```

postcard4cj 使用增量 COBS block 构造，pending segment 最大为 254 字节，不需要在 finalize 时复制第二份完整消息。

## 7. CRC32C/iSCSI 帧

```cangjie
let packet = toBytesCrc32Iscsi<Message>(source)
let decoded = fromBytesCrc32Iscsi<Message>(packet)
```

解码器会先验证附加的 CRC32C 校验值，再返回消息。校验失败会抛出明确的 CRC mismatch 异常类别。

对于连续数据可使用：

```cangjie
let result = takeFromBytesCrc32Iscsi<Message>(stream)
```

## 8. Enum

```cangjie
@Postcard
public enum Command {
    | Ping
    | SetSpeed(UInt16)
    | Rename(String, Bool)
}
```

支持：

- unit variant
- newtype variant
- tuple variant
- struct variant

枚举必须是 exhaustive。变体编码索引遵循声明顺序，因此不要在已发布协议中随意调整已有变体顺序。

## 9. 泛型类型

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

宏会为每个类型参数生成所需的 codec 上界。已有 `where` 上界会通过 AST 与自动生成的 Postcard 上界合并。

泛型 struct 和 exhaustive enum 均支持一个或多个类型参数。

## 10. Schema

```cangjie
@PostcardSchema
public struct SchemaMessage {
    public let id: UInt32

    public init(id: UInt32) {
        this.id = id
    }
}
```

NG 入口为：

```cangjie
@PostcardSchemaNg
```

需要自定义 Schema 名称时，使用命名宏：

```cangjie
@PostcardSchemaNamed["wire_record", "id=wire_id"]
public struct Record {
    public let id: UInt32
}
```

命名配置只影响 Schema 元数据，不改变实际 wire bytes。

## 11. 最大序列化尺寸

```cangjie
@PostcardMaxSize
public struct BoundedMessage {
    public let id: UInt32

    public init(id: UInt32) {
        this.id = id
    }
}
```

- `serializedSize(value)`：计算某个具体值的编码尺寸；
- `PostcardMaxSize`：描述有界类型的最大未加 Flavor 尺寸。

未提供上限的 String 或 Array 无法静态计算最大尺寸，因此 MaxSize 宏会拒绝这类字段。可改用有界包装类型或手动实现。

## 12. 手动实现 Codec

不使用宏时，可以实现核心接口：

```cangjie
public interface PostcardEncode {
    func encode(encoder: PostcardEncoder): Unit
}

public interface PostcardDecode<T> {
    static func decode(decoder: PostcardDecoder): T
}
```

手动实现时，编码与解码字段顺序必须严格一致。

## 13. 安全建议

解码外部输入时应遵循：

1. 将所有长度字段视为不可信数据；
2. 对业务集合设置额外的应用层数量上限；
3. 单消息缓冲区使用严格解码；
4. 只有明确处理消息流时才使用 remainder API；
5. 在执行任何业务动作前完成 COBS/CRC 校验；
6. 不要吞掉 malformed-input 异常。

postcard4cj 已避免直接使用恶意声明长度进行大容量预分配，但应用层仍应根据业务限制消息和集合规模。

## 14. 常见选择

| 需求 | 推荐 API |
|---|---|
| 普通字节数组编码 | `toBytes<T>` |
| 单条消息严格解码 | `fromBytes<T>` / `fromByteArray<T>` |
| 拼接消息流 | `takeFromByteArray<T>` |
| 零分隔串口帧 | `toBytesCobs<T>` / `fromBytesCobs<T>` |
| 需要传输校验 | `toBytesCrc32Iscsi<T>` / `fromBytesCrc32Iscsi<T>` |
| 固定缓冲区 | Slice / fixed-capacity Flavor |
| 流式读写 | `postcard4cj.io` 或 `postcard4cj.v2_eio` |
| 运行时 Schema | `postcard4cj.schema` |
| 无损动态值 | `postcard4cj.dynamic` |
| Postcard2 风格 | `postcard4cj.v2` |

## 15. 下一步

- [功能与 API 指南](feature_api.zh-CN.md)
- [从 Rust Postcard 迁移](migration.zh-CN.md)
- [英文架构设计](design.md)
- [覆盖率报告](cjcov/README.md)
- [Benchmark](benchmark.md)

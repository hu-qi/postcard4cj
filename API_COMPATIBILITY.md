# Public API compatibility audit

Baseline: `jamesmunns/postcard@de182557cff45f2ca9b2b67a6b93be5917612a44`.

Cangjie follows camelCase naming while Rust uses snake_case. A mapping marked **Implemented** preserves the behavior and wire format, even when the spelling or ownership model differs.

## `postcard-core`

### Serialization primitives

| Rust concept | Cangjie mapping | Status |
|---|---|---|
| `ser::Flavor` | `postcard4cj.flavors.SerializeFlavor` | Implemented |
| `try_push_bool` | `CoreEncoder.pushBool` | Implemented |
| `try_push_i8/i16/i32/i64/i128` | `CoreEncoder.pushInt8/16/32/64/128` | Implemented |
| `try_push_u8/u16/u32/u64/u128` | `CoreEncoder.pushUInt8/16/32/64/128` | Implemented |
| `try_push_isize/usize` | `CoreEncoder.pushPlatformInt/UInt` | Implemented with 64-bit runtime substitution |
| `try_push_f32/f64` | `CoreEncoder.pushFloat32/64` | Implemented |
| `try_push_char` | `CoreEncoder.pushRune` | Implemented |
| `try_push_str` | `CoreEncoder.pushString` | Implemented |
| `try_push_bytes` | `CoreEncoder.pushBytes` | Implemented |
| `try_push_option_none/some` | `CoreEncoder.pushOptionNone/Some` | Implemented |
| `try_push_discriminant` | `CoreEncoder.pushDiscriminant` | Implemented |
| `try_push_length` | `CoreEncoder.pushLength` | Implemented |

### Deserialization primitives

| Rust concept | Cangjie mapping | Status |
|---|---|---|
| `de::Flavor<'de>` | `postcard4cj.flavors.DeserializeFlavor` | Implemented; lifetime-free Cangjie ownership model |
| `try_take_bool` | `CoreDecoder.takeBool` | Implemented |
| `try_take_i8/i16/i32/i64/i128` | `CoreDecoder.takeInt8/16/32/64/128` | Implemented |
| `try_take_u8/u16/u32/u64/u128` | `CoreDecoder.takeUInt8/16/32/64/128` | Implemented |
| `try_take_isize/usize` | `CoreDecoder.takePlatformInt/UInt` | Implemented with 64-bit runtime substitution |
| `try_take_f32/f64` | `CoreDecoder.takeFloat32/64` | Implemented |
| `try_take_char` | `CoreDecoder.takeRune` | Implemented |
| `try_take_str` / `_temp` | `CoreDecoder.takeString` | Implemented as owned Cangjie String |
| `try_take_bytes` / `_temp` | `CoreDecoder.takeBytes` | Implemented as Array/slice value |
| `try_take_option_discrim` | `CoreDecoder.takeOptionDiscriminant` | Implemented |
| `try_take_discriminant` | `CoreDecoder.takeDiscriminant` | Implemented |
| `try_take_length` | `CoreDecoder.takeLength` | Implemented |

## `postcard`

### Top-level serialization

| Rust API | Cangjie mapping | Status |
|---|---|---|
| `Serializer<F>` | `postcard4cj.serde_model.Serializer` | Implemented |
| `serialize_with_flavor` | `serializeWithFlavor` | Implemented |
| `to_slice` | `toSlice` / `encodeTo` | Implemented |
| `to_extend` | `ExtendSerializeFlavor`, `toExtendV2` | Implemented as `ByteExtendSink` |
| `to_vec` | `toByteArray`, `toVecV2` | Implemented; Cangjie Array replaces heapless default |
| `to_allocvec` | `toByteArray` | Implemented; Array is the owned collection |
| `to_stdvec` | `toByteArray` | Implemented; no separate std/alloc collection split |
| `to_eio` | `toEioV2` | Implemented via `ByteWriter` |
| `to_io` | `postcard4cj.io.toIo` | Implemented via `ByteWriter` |
| `to_slice_cobs` | `serializeWithFlavor(... CobsSerializeFlavor(...))`, `toBytesCobs` | Implemented |
| `to_vec_cobs` / `to_allocvec_cobs` / `to_stdvec_cobs` | COBS Flavor with Array storage | Implemented |
| `to_slice_crc32` | CRC Flavor or `toBytesCrc32Iscsi` | Implemented |
| `to_vec_crc32` / alloc/std variants | CRC Flavor with selected storage | Implemented |

### Top-level deserialization

| Rust API | Cangjie mapping | Status |
|---|---|---|
| `Deserializer<F>` | `postcard4cj.serde_model.Deserializer` | Implemented |
| `from_bytes` | `fromByteArray`; `fromBytesV2` for postcard2 semantics | Implemented |
| `take_from_bytes` | `takeFromByteArray` / `takeFromBytesV2` | Implemented |
| `from_bytes_cobs` | `CobsDeserializeFlavor`, `fromBytesCobs` | Implemented |
| `take_from_bytes_cobs` | `takeDynamicWithFlavor` or typed Deserializer with COBS Flavor | Implemented behavior; convenience alias audit pending |
| `from_bytes_crc32` | `Crc32DeserializeFlavor`, `fromBytesCrc32Iscsi` | Implemented |
| `take_from_bytes_crc32` | typed Deserializer with CRC Flavor | Implemented behavior; convenience alias audit pending |
| `from_eio` | `fromEioV2` | Implemented via `ByteReader` and scratch buffer |
| `from_io` | `postcard4cj.io.fromIo` | Implemented via `ByteReader` and scratch buffer |

### Flavors

| Rust Flavor | Cangjie mapping | Status |
|---|---|---|
| `ser_flavors::Slice` | `SliceSerializeFlavor` | Implemented |
| `ser_flavors::HVec` | `FixedVecFlavor` | Implemented with runtime capacity |
| `ser_flavors::AllocVec` / `StdVec` | `ArraySerializeFlavor` | Implemented |
| `ser_flavors::ExtendFlavor` | `ExtendSerializeFlavor` | Implemented |
| `ser_flavors::WriteFlavor` | `v2_eio.WriteFlavor` | Implemented |
| `ser_flavors::Cobs` | `CobsSerializeFlavor` | Implemented; buffered transform |
| `ser_flavors::CrcModifier` | `Crc32SerializeFlavor` | Implemented; buffered transform |
| size-counting Flavor | `SizeSerializeFlavor` | Implemented |
| `de_flavors::Slice` | `SliceDeserializeFlavor` | Implemented |
| IO/EIO reader Flavor | `v2_eio.ReaderFlavor` | Implemented |
| COBS source | `CobsDeserializeFlavor` | Implemented |
| CRC source | `Crc32DeserializeFlavor` | Implemented |

### Other modules

| Rust API | Cangjie mapping | Status |
|---|---|---|
| `Error`, `Result` | `PostcardErrorKind`, `PostcardException` | Implemented; exceptions replace Result return type |
| `accumulator::CobsAccumulator<N>` | `CobsAccumulator(capacity)` | Implemented with runtime capacity |
| `fixint::le/be` wrappers | `postcard4cj.fixint` LE/BE functions | Implemented |
| `experimental::serialized_size` | `serializedSize` | Implemented |
| `experimental::max_size::MaxSize` | `PostcardMaxSize` | Implemented |
| derive `MaxSize` | `@PostcardMaxSize` | Implemented for bounded non-generic declarations |

## `postcard-derive`

| Rust derive | Cangjie mapping | Status |
|---|---|---|
| `#[derive(MaxSize)]` | `@PostcardMaxSize` | Implemented for bounded non-generic struct/enum forms |
| `#[derive(Schema)]` | `@PostcardSchema` | Implemented for non-generic struct/enum forms |
| Serde codec derives | `@Postcard` | Implemented for non-generic struct/enum forms |
| `#[serde(rename = ...)]` / postcard rename | Manual Schema or codec declaration | Pending macro attribute audit |
| generic bounds | Manual implementation | Pending Cangjie generic-macro audit |

## `postcard-schema`

| Rust API | Cangjie mapping | Status |
|---|---|---|
| `Schema` trait | `PostcardSchema<T>` | Implemented |
| `NamedType` | `postcard4cj.schema.NamedType` | Implemented |
| `DataModelType` | `DataModelType` | Implemented; `Bool`/`Unit` names changed to avoid keywords, wire indices retained |
| `NamedValue` | `NamedValue` | Implemented |
| `NamedVariant` | `NamedVariant` | Implemented |
| `DataModelVariant` | `DataModelVariant` | Implemented |
| owned schema tree | single runtime-owned Schema graph + `toOwnedSchema` | Deliberate Cangjie substitution |
| Schema serialization | `PostcardSerialize` implementations | Implemented |
| Schema formatting | `formatSchema` | Implemented |
| recursive used types | `allUsedTypes` | Implemented |
| `Key` / hash v2 | `Key`, `keyForPath`, `keyForSchemaPath` | Implemented with upstream FNV markers |
| primitive/container impls | Schema constructor helpers and macros | Implemented core set; optional integration audit pending |

## `postcard-schema-ng` / `postcard-derive-ng`

| Rust concept | Cangjie mapping | Status |
|---|---|---|
| NG Schema trait | `PostcardSchemaNg<T>` | Implemented |
| NG derive Schema | `@PostcardSchemaNg` | Implemented |
| NG derive MaxSize | `@PostcardMaxSizeNg` | Implemented |
| NG owned tree / key | shared validated runtime tree, `toOwnedSchemaNg`, `keyForPathNg` | Implemented |

## `postcard-dyn`

| Rust API/concept | Cangjie mapping | Status |
|---|---|---|
| schema-directed deserialize to `serde_json::Value` | `fromByteArrayDynamicJson` | Implemented |
| schema-directed serialize from `serde_json::Value` | `toByteArrayDynamicJson` | Implemented |
| `DeError` categories | `DynamicErrorKind`, `DynamicException` | Implemented |
| JSON Null/Bool/Number/String/Array/Object | `JsonValue` | Implemented |
| lossless value model | `DynamicValue` | Additional Cangjie capability |
| arbitrary-key maps | `DynamicValue.MapValue` | Additional Cangjie capability |
| explicit `None` vs `Some(Unit)` | `DynamicOption` | Additional Cangjie capability |
| Schema as a Dynamic value | `DynamicValue.SchemaValue` | Implemented outside JSON conversion |

## `postcard-dyn-ng`

| Rust concept | Cangjie mapping | Status |
|---|---|---|
| NG dynamic codec | `postcard4cj.dynamic_ng` | Implemented |
| NG JSON conversion | `toByteArrayDynamicJsonNg`, `fromByteArrayDynamicJsonNg` | Implemented |
| NG remainder and Flavor APIs | `takeFromByteArrayDynamicNg`, `takeDynamicWithFlavorNg` | Implemented |

## `postcard2`

| Rust API | Cangjie mapping | Status |
|---|---|---|
| `Serializer<F>` | `V2Serializer` and core-backed `Serializer` | Implemented |
| `Deserializer<F>` | `V2Deserializer` and core-backed `Deserializer` | Implemented |
| `SerializerError<PE, FE>` | `SerializerErrorKind`, `SerializerException` | Implemented without generic error payload types |
| `DeserializerError<PE, FE>` | `DeserializerErrorKind`, `DeserializerException` | Implemented without generic error payload types |
| `to_slice` | `toSliceV2` | Implemented |
| `to_vec` | `toVecV2` | Implemented |
| `to_extend` | `toExtendV2` | Implemented with `ByteExtendSink` |
| `serialized_size` | `serializedSizeV2` | Implemented |
| `from_bytes` | `fromBytesV2` | Implemented; trailing bytes ignored like upstream |
| `take_from_bytes` | `takeFromBytesV2` | Implemented |

## `postcard2-eio`

| Rust API | Cangjie mapping | Status |
|---|---|---|
| embedded-io 0.7 Write Flavor | `ByteWriter`, `WriteFlavor` | Implemented |
| embedded-io 0.7 Reader Flavor | `ByteReader`, `ReaderFlavor` | Implemented |
| `to_eio` | `toEioV2` | Implemented |
| `from_eio` | `fromEioV2` | Implemented |
| reader + unused buffer return | `EioDeserializeResult<T>` | Implemented |

## `postcard2-heapless`

| Rust API | Cangjie mapping | Status |
|---|---|---|
| `HVec<const B: usize>` | `FixedByteVec(capacity)` | Implemented with runtime capacity |
| HVec Flavor | `FixedVecFlavor` | Implemented |
| fixed vector helper | `toFixedVecV2` | Implemented |

## Optional upstream integrations under audit

The upstream feature matrix includes integrations not yet claimed as release-ready:

- UUID 1.x
- chrono 0.4
- nalgebra 0.33 / 0.34
- fixed 1.x
- defmt
- serde-big-array
- historical heapless 0.7 / 0.8 / 0.9 aliases
- embedded-io 0.4 / 0.6 compatibility aliases

These do not change the Postcard wire format. Each will receive either a Cangjie-native adapter, a direct statement that the native Cangjie type already implements the core interfaces, or an explicit exclusion before the PR leaves Draft.

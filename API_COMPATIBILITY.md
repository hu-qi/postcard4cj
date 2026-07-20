# Public API compatibility audit

Behavior baseline: `jamesmunns/postcard@de182557cff45f2ca9b2b67a6b93be5917612a44`.

postcard4cj is implemented entirely in Cangjie. This document maps upstream concepts to Cangjie APIs; it does not describe a Rust implementation or runtime dependency. Cangjie follows camelCase naming while the upstream API uses snake_case. A mapping marked **Implemented** preserves the wire format and observable behavior, subject to the documented language-level substitutions.

## `postcard-core`

### Serialization primitives

| Upstream concept | Cangjie mapping | Status |
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

| Upstream concept | Cangjie mapping | Status |
|---|---|---|
| `de::Flavor<'de>` | `postcard4cj.flavors.DeserializeFlavor` | Implemented with lifetime-free Cangjie ownership |
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

| Upstream API | Cangjie mapping | Status |
|---|---|---|
| `Serializer<F>` | `postcard4cj.serde_model.Serializer` | Implemented |
| `serialize_with_flavor` | `serializeWithFlavor` | Implemented |
| `to_slice` | `toSlice` / `encodeTo` | Implemented |
| `to_extend` | `ExtendSerializeFlavor`, `toExtendV2` | Implemented as `ByteExtendSink` |
| `to_vec` | `toByteArray`, `toVecV2` | Implemented; Cangjie Array is the owned collection |
| `to_allocvec` | `toByteArray` | Implemented |
| `to_stdvec` | `toByteArray` | Implemented; no std/alloc collection split |
| `to_eio` | `toEioV2` | Implemented via `ByteWriter` |
| `to_io` | `postcard4cj.io.toIo` | Implemented via `ByteWriter` |
| `to_slice_cobs` | `serializeWithFlavor(... CobsSerializeFlavor(...))`, `toBytesCobs`, `encodeToCobs` | Implemented |
| `to_vec_cobs` / owned variants | COBS Flavor with Array storage | Implemented |
| `to_slice_crc32` | CRC Flavor, `toBytesCrc32Iscsi`, `encodeToCrc32Iscsi` | Implemented |
| `to_vec_crc32` / owned variants | CRC Flavor with selected storage | Implemented |

### Top-level deserialization

| Upstream API | Cangjie mapping | Status |
|---|---|---|
| `Deserializer<F>` | `postcard4cj.serde_model.Deserializer` | Implemented |
| `from_bytes` | `fromByteArray`; `fromBytesV2` for postcard2 semantics | Implemented |
| `take_from_bytes` | `takeFromByteArray` / `takeFromBytesV2` | Implemented |
| `from_bytes_cobs` | `CobsDeserializeFlavor`, `fromBytesCobs` | Implemented |
| `take_from_bytes_cobs` | `takeFromBytesCobs` | Implemented with bytes after the first frame delimiter returned as remainder |
| `from_bytes_crc32` | `Crc32DeserializeFlavor`, `fromBytesCrc32Iscsi` | Implemented |
| `take_from_bytes_crc32` | `takeFromBytesCrc32Iscsi` | Implemented with bytes after the validated checksum returned as remainder |
| `from_eio` | `fromEioV2` | Implemented via `ByteReader` and scratch buffer |
| `from_io` | `postcard4cj.io.fromIo` | Implemented via `ByteReader` and scratch buffer |

### Flavors

| Upstream Flavor | Cangjie mapping | Status |
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

| Upstream API | Cangjie mapping | Status |
|---|---|---|
| `Error`, `Result` | `PostcardErrorKind`, `PostcardException` | Implemented; exceptions are the Cangjie error surface |
| `accumulator::CobsAccumulator<N>` | `CobsAccumulator(capacity)` | Implemented with runtime capacity |
| `fixint::le/be` wrappers | `postcard4cj.fixint` LE/BE functions | Implemented |
| `experimental::serialized_size` | `serializedSize` | Implemented |
| `experimental::max_size::MaxSize` | `PostcardMaxSize` | Implemented |
| derive `MaxSize` | `@PostcardMaxSize` | Implemented for bounded non-generic declarations and generic structs with one or more parameters when no existing `where` clause is present |

## `postcard-derive`

| Upstream derive capability | Cangjie mapping | Status |
|---|---|---|
| MaxSize derive | `@PostcardMaxSize` | Implemented for bounded non-generic declarations and generic structs with one or more parameters without existing `where` constraints |
| Schema derive | `@PostcardSchema` | Implemented for non-generic declarations and generic structs with one or more parameters without existing `where` constraints |
| codec derive | `@Postcard` | Implemented for non-generic declarations and generic structs with one or more parameters without existing `where` constraints |
| rename attributes | Manual Schema or codec declaration | Pending macro attribute implementation |
| constrained generic declarations | Manual implementation | Pending constraint-merging support |
| generic enums | Non-generic payload wrapper or manual implementation | Pending generic enum support |

## `postcard-schema`

| Upstream API | Cangjie mapping | Status |
|---|---|---|
| `Schema` trait | `PostcardSchema<T>` | Implemented |
| `NamedType` | `postcard4cj.schema.NamedType` | Implemented |
| `DataModelType` | `DataModelType` | Implemented; keyword-conflicting member names are changed while wire indices remain stable |
| `NamedValue` | `NamedValue` | Implemented |
| `NamedVariant` | `NamedVariant` | Implemented |
| `DataModelVariant` | `DataModelVariant` | Implemented |
| owned schema tree | one runtime-owned Schema graph + `toOwnedSchema` | Deliberate Cangjie substitution |
| Schema serialization | `PostcardSerialize` implementations | Implemented |
| Schema formatting | `formatSchema` | Implemented |
| recursive used types | `allUsedTypes` | Implemented |
| `Key` / hash v2 | `Key`, `keyForPath`, `keyForSchemaPath` | Implemented with upstream FNV markers |
| primitive/container implementations | Schema constructor helpers and macros | Implemented core set; optional adapter audit pending |

## `postcard-schema-ng` / `postcard-derive-ng`

| Upstream concept | Cangjie mapping | Status |
|---|---|---|
| NG Schema trait | `PostcardSchemaNg<T>` | Implemented |
| NG Schema derive | `@PostcardSchemaNg` | Implemented for non-generic declarations and generic structs with one or more parameters without existing `where` constraints |
| NG MaxSize derive | `@PostcardMaxSizeNg` | Implemented for bounded non-generic declarations and generic structs with one or more parameters without existing `where` constraints |
| NG owned tree / key | shared runtime tree, `toOwnedSchemaNg`, `keyForPathNg` | Implemented |

## `postcard-dyn`

| Upstream API/concept | Cangjie mapping | Status |
|---|---|---|
| schema-directed deserialize to a JSON value | `fromByteArrayDynamicJson` | Implemented |
| schema-directed serialize from a JSON value | `toByteArrayDynamicJson` | Implemented |
| dynamic error categories | `DynamicErrorKind`, `DynamicException` | Implemented |
| JSON Null/Bool/Number/String/Array/Object | `JsonValue` | Implemented |
| lossless value model | `DynamicValue` | Additional Cangjie capability |
| arbitrary-key maps | `DynamicValue.MapValue` | Additional Cangjie capability |
| explicit `None` vs `Some(Unit)` | `DynamicOption` | Additional Cangjie capability |
| Schema as a Dynamic value | `DynamicValue.SchemaValue` | Implemented outside JSON conversion |

## `postcard-dyn-ng`

| Upstream concept | Cangjie mapping | Status |
|---|---|---|
| NG dynamic codec | `postcard4cj.dynamic_ng` | Implemented |
| NG JSON conversion | `toByteArrayDynamicJsonNg`, `fromByteArrayDynamicJsonNg` | Implemented |
| NG remainder and Flavor APIs | `takeFromByteArrayDynamicNg`, `takeDynamicWithFlavorNg` | Implemented |

## `postcard2`

| Upstream API | Cangjie mapping | Status |
|---|---|---|
| `Serializer<F>` | `V2Serializer` and core-backed `Serializer` | Implemented |
| `Deserializer<F>` | `V2Deserializer` and core-backed `Deserializer` | Implemented |
| generic serializer error | `SerializerErrorKind`, `SerializerException` | Implemented without generic error payload types |
| generic deserializer error | `DeserializerErrorKind`, `DeserializerException` | Implemented without generic error payload types |
| `to_slice` | `toSliceV2` | Implemented |
| `to_vec` | `toVecV2` | Implemented |
| `to_extend` | `toExtendV2` | Implemented with `ByteExtendSink` |
| `serialized_size` | `serializedSizeV2` | Implemented |
| `from_bytes` | `fromBytesV2` | Implemented; trailing bytes ignored like upstream behavior |
| `take_from_bytes` | `takeFromBytesV2` | Implemented |

## `postcard2-eio`

| Upstream API | Cangjie mapping | Status |
|---|---|---|
| embedded-IO Write Flavor | `ByteWriter`, `WriteFlavor` | Implemented |
| embedded-IO Reader Flavor | `ByteReader`, `ReaderFlavor` | Implemented |
| `to_eio` | `toEioV2` | Implemented |
| `from_eio` | `fromEioV2` | Implemented |
| reader + unused buffer return | `EioDeserializeResult<T>` | Implemented |

## `postcard2-heapless`

| Upstream API | Cangjie mapping | Status |
|---|---|---|
| fixed byte vector | `FixedByteVec(capacity)` | Implemented with runtime capacity |
| fixed-vector Flavor | `FixedVecFlavor` | Implemented |
| fixed-vector helper | `toFixedVecV2` | Implemented |

## Pure Cangjie verification

The repository contains no Rust source or Cargo project. Compatibility checks are Cangjie tests with fixed Golden Vectors and negative cases. CI rejects `.rs`, `Cargo.toml`, `Cargo.lock`, Rust toolchain files, and `.cargo` before building.

Latest validation: **173 Cangjie tests passed, 0 failed, 0 skipped, 0 errors**.

## Optional ecosystem integrations under audit

The upstream feature matrix contains ecosystem integrations that require Cangjie-native decisions:

- UUID
- date/time types corresponding to chrono usage
- matrix/vector types corresponding to nalgebra usage
- fixed-point number types
- diagnostic formatting corresponding to defmt usage
- large fixed-array helpers
- historical bounded-vector compatibility aliases
- historical embedded-IO compatibility aliases

Each item will receive a Cangjie-native adapter, a statement that the native type can use the core interfaces directly, or an explicit exclusion. None of these items is implemented by embedding Rust code.

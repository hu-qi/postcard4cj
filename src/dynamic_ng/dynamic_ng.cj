package postcard4cj.dynamic_ng

import postcard4cj.dynamic.*
import postcard4cj.flavors.*
import postcard4cj.schema.*

/** Serialize a lossless dynamic value through the NG compatibility namespace. */
public func toByteArrayDynamicNg(schema: NamedType, value: DynamicValue): Array<UInt8> {
    return toByteArrayDynamic(schema, value)
}

public func serializeDynamicWithFlavorNg(
    schema: NamedType,
    value: DynamicValue,
    flavor: SerializeFlavor
): Array<UInt8> {
    return serializeDynamicWithFlavor(schema, value, flavor)
}

public func fromByteArrayDynamicNg(schema: NamedType, input: Array<UInt8>): DynamicValue {
    return fromByteArrayDynamic(schema, input)
}

public func takeFromByteArrayDynamicNg(
    schema: NamedType,
    input: Array<UInt8>
): (DynamicValue, Array<UInt8>) {
    return takeFromByteArrayDynamic(schema, input)
}

public func takeDynamicWithFlavorNg(
    schema: NamedType,
    flavor: DeserializeFlavor
): (DynamicValue, Array<UInt8>) {
    return takeDynamicWithFlavor(schema, flavor)
}

/** serde_json-compatible NG adapters. */
public func toByteArrayDynamicJsonNg(schema: NamedType, value: JsonValue): Array<UInt8> {
    return toByteArrayDynamicJson(schema, value)
}

public func fromByteArrayDynamicJsonNg(schema: NamedType, input: Array<UInt8>): JsonValue {
    return fromByteArrayDynamicJson(schema, input)
}

public func jsonToDynamicNg(schema: NamedType, value: JsonValue): DynamicValue {
    return jsonToDynamic(schema, value)
}

public func dynamicToJsonNg(schema: NamedType, value: DynamicValue): JsonValue {
    return dynamicToJson(schema, value)
}

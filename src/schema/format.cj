package postcard4cj.schema

import std.collection.*

/** Whether the schema is represented as a primitive-like inline value. */
public func isPrimitiveSchema(value: DataModelType): Bool {
    return match (value) {
        case DataModelType.Bool => true
        case DataModelType.I8 => true
        case DataModelType.U8 => true
        case DataModelType.I16 => true
        case DataModelType.I32 => true
        case DataModelType.I64 => true
        case DataModelType.I128 => true
        case DataModelType.U16 => true
        case DataModelType.U32 => true
        case DataModelType.U64 => true
        case DataModelType.U128 => true
        case DataModelType.Usize => true
        case DataModelType.Isize => true
        case DataModelType.F32 => true
        case DataModelType.F64 => true
        case DataModelType.Char => true
        case DataModelType.StringValue => true
        case DataModelType.ByteArray => true
        case DataModelType.Option(inner) => isPrimitiveSchema(inner.ty)
        case DataModelType.Unit => true
        case DataModelType.UnitStruct => true
        case DataModelType.NewtypeStruct(inner) => isPrimitiveSchema(inner.ty)
        case DataModelType.Seq(_) => false
        case DataModelType.Tuple(_) => false
        case DataModelType.TupleStruct(elements) => allPrimitive(elements)
        case DataModelType.Map(key, val) =>
            isPrimitiveSchema(key.ty) && isPrimitiveSchema(val.ty)
        case DataModelType.Struct(_) => false
        case DataModelType.Enum(_) => false
        case DataModelType.Schema => true
    }
}

private func allPrimitive(values: Array<NamedType>): Bool {
    for (value in values) {
        if (!isPrimitiveSchema(value.ty)) {
            return false
        }
    }
    return true
}

private func joinStrings(values: Array<String>, separator: String): String {
    var output = ""
    var index = 0i64
    while (index < values.size) {
        if (index > 0) {
            output += separator
        }
        output += values[index]
        index++
    }
    return output
}

private func formatNamedTypes(values: Array<NamedType>): String {
    return joinStrings(
        Array<String>(values.size, {index: Int64 => formatSchemaNested(values[index])}),
        ", "
    )
}

private func formatNamedValues(values: Array<NamedValue>): String {
    return joinStrings(
        Array<String>(values.size, {index: Int64 =>
            "${values[index].name}: ${formatSchemaNested(values[index].ty)}"
        }),
        ", "
    )
}

private func homogeneousTuple(values: Array<NamedType>): Bool {
    if (values.size == 0) {
        return false
    }
    let first = formatSchema(values[0])
    var index = 1i64
    while (index < values.size) {
        if (formatSchema(values[index]) != first) {
            return false
        }
        index++
    }
    return true
}

private func formatVariant(value: NamedVariant): String {
    return match (value.ty) {
        case DataModelVariant.UnitVariant => value.name
        case DataModelVariant.NewtypeVariant(inner) =>
            "${value.name}(${formatSchemaNested(inner)})"
        case DataModelVariant.TupleVariant(elements) =>
            "${value.name}(${formatNamedTypes(elements)})"
        case DataModelVariant.StructVariant(fields) =>
            "${value.name} { ${formatNamedValues(fields)} }"
    }
}

private func formatSchemaNested(value: NamedType): String {
    return formatSchemaInternal(value, false)
}

private func formatSchemaInternal(value: NamedType, topLevel: Bool): String {
    return match (value.ty) {
        case DataModelType.Bool => "bool"
        case DataModelType.I8 => "i8"
        case DataModelType.U8 => "u8"
        case DataModelType.I16 => "i16"
        case DataModelType.I32 => "i32"
        case DataModelType.I64 => "i64"
        case DataModelType.I128 => "i128"
        case DataModelType.U16 => "u16"
        case DataModelType.U32 => "u32"
        case DataModelType.U64 => "u64"
        case DataModelType.U128 => "u128"
        case DataModelType.Usize => "usize"
        case DataModelType.Isize => "isize"
        case DataModelType.F32 => "f32"
        case DataModelType.F64 => "f64"
        case DataModelType.Char => "char"
        case DataModelType.StringValue => "String"
        case DataModelType.ByteArray => "[u8]"
        case DataModelType.Option(inner) => "Option<${formatSchemaNested(inner)}>"
        case DataModelType.Unit => "()"
        case DataModelType.UnitStruct => if (topLevel) { "struct ${value.name}" } else { value.name }
        case DataModelType.NewtypeStruct(inner) =>
            if (topLevel) {
                "struct ${value.name}(${formatSchemaNested(inner)})"
            } else {
                value.name
            }
        case DataModelType.Seq(inner) => "[${formatSchemaNested(inner)}]"
        case DataModelType.Tuple(elements) =>
            if (elements.size == 0) {
                "()"
            } else if (homogeneousTuple(elements)) {
                "[${formatSchemaNested(elements[0])}; ${elements.size}]"
            } else {
                "(${formatNamedTypes(elements)})"
            }
        case DataModelType.TupleStruct(elements) =>
            if (topLevel) {
                "struct ${value.name}(${formatNamedTypes(elements)})"
            } else {
                value.name
            }
        case DataModelType.Map(key, val) =>
            "Map<${formatSchemaNested(key)}, ${formatSchemaNested(val)}>"
        case DataModelType.Struct(fields) =>
            if (topLevel) {
                "struct ${value.name} { ${formatNamedValues(fields)} }"
            } else {
                value.name
            }
        case DataModelType.Enum(variants) =>
            if (topLevel) {
                let rendered = Array<String>(variants.size, {index: Int64 =>
                    formatVariant(variants[index])
                })
                "enum ${value.name} { ${joinStrings(rendered, ", ")} }"
            } else {
                value.name
            }
        case DataModelType.Schema => "Schema"
    }
}

/** Convert an owned schema into the upstream pseudo-Rust display format. */
public func formatSchema(value: NamedType): String {
    return formatSchemaInternal(value, true)
}

private func containsString(values: ArrayList<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    return false
}

private func discover(value: NamedType, output: ArrayList<NamedType>, identities: ArrayList<String>): Unit {
    let identity = formatSchema(value)
    if (containsString(identities, identity)) {
        return
    }
    identities.add(identity)
    output.add(value)

    match (value.ty) {
        case DataModelType.Option(inner) => discover(inner, output, identities)
        case DataModelType.NewtypeStruct(inner) => discover(inner, output, identities)
        case DataModelType.Seq(inner) => discover(inner, output, identities)
        case DataModelType.Tuple(elements) =>
            for (element in elements) { discover(element, output, identities) }
        case DataModelType.TupleStruct(elements) =>
            for (element in elements) { discover(element, output, identities) }
        case DataModelType.Map(key, val) =>
            discover(key, output, identities)
            discover(val, output, identities)
        case DataModelType.Struct(fields) =>
            for (field in fields) { discover(field.ty, output, identities) }
        case DataModelType.Enum(variants) =>
            for (variant in variants) {
                match (variant.ty) {
                    case DataModelVariant.UnitVariant => ()
                    case DataModelVariant.NewtypeVariant(inner) =>
                        discover(inner, output, identities)
                    case DataModelVariant.TupleVariant(elements) =>
                        for (element in elements) { discover(element, output, identities) }
                    case DataModelVariant.StructVariant(fields) =>
                        for (field in fields) { discover(field.ty, output, identities) }
                }
            }
        case _ => ()
    }
}

/** Collect every unique named type used recursively by the supplied schema. */
public func allUsedTypes(value: NamedType): Array<NamedType> {
    let output = ArrayList<NamedType>()
    let identities = ArrayList<String>()
    discover(value, output, identities)
    return output.toArray()
}

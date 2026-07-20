macro package postcard4cj.derive_ng

import std.ast.*

private func ngSchemaPrimitive(typeName: String): String {
    return match (typeName) {
        case "UInt8" => "uint8Schema()"
        case "UInt16" => "uint16Schema()"
        case "UInt32" => "uint32Schema()"
        case "UInt64" => "uint64Schema()"
        case "Int8" => "int8Schema()"
        case "Int16" => "int16Schema()"
        case "Int32" => "int32Schema()"
        case "Int64" => "int64Schema()"
        case "Float32" => "float32Schema()"
        case "Float64" => "float64Schema()"
        case "Bool" => "boolSchema()"
        case "String" => "stringSchema()"
        case "Rune" => "runeSchema()"
        case "Unit" => "unitSchema()"
        case "PostcardUInt128" => "uint128Schema()"
        case "PostcardInt128" => "int128Schema()"
        case _ => ""
    }
}

private func ngSchemaExpression(typeNode: TypeNode): String {
    let rendered = typeNode.toTokens().toString()
    let primitive = ngSchemaPrimitive(rendered)
    if (primitive.size > 0) {
        return primitive
    }
    let reference = match (typeNode as RefType) {
        case Some(value) => value
        case None => return "${rendered}.schemaNg()"
    }
    let identifier = reference.identifier.value
    if (identifier == "BigInt") {
        diagReport(
            DiagReportLevel.ERROR,
            typeNode.toTokens(),
            "@PostcardSchemaNg cannot infer BigInt signedness",
            "Use PostcardInt128 or PostcardUInt128."
        )
        return "unitSchema()"
    }
    if (identifier == "Option" || identifier == "Array") {
        if (reference.typeArguments.size != 1) {
            diagReport(
                DiagReportLevel.ERROR,
                typeNode.toTokens(),
                "@PostcardSchemaNg expects one type argument",
                "Use Option<T> or Array<T>."
            )
            return "unitSchema()"
        }
        let inner = ngSchemaExpression(reference.typeArguments[0])
        if (identifier == "Option") {
            return "optionSchema(${inner})"
        }
        return "sequenceSchema(${inner})"
    }
    return "${rendered}.schemaNg()"
}

private func ngHasModifier(declaration: Decl, modifierName: String): Bool {
    for (modifier in declaration.modifiers) {
        if (modifier.keyword.value == modifierName) {
            return true
        }
    }
    return false
}

private func ngSchemaGenericParameterList(declaration: Decl): String {
    return declaration.genericParam.parameters.toString()
}

private func ngSchemaGenericBounds(declaration: Decl): String {
    var bounds = ""
    var first = true
    for (token in declaration.genericParam.parameters) {
        let name = token.value
        if (name.size == 0 || name == "," || name == "\n") { continue }
        if (!first) { bounds += ", " }
        bounds += "${name} <: PostcardSchemaNg<${name}>"
        first = false
    }
    return bounds
}

private func generateNgStruct(input: Tokens, declaration: StructDecl): Tokens {
    var genericParameters = ""
    var genericConstraints = ""
    if (declaration.isGenericDecl) {
        if (declaration.genericConstraint.size > 0) {
            diagReport(
                DiagReportLevel.ERROR,
                input,
                "@PostcardSchemaNg generic structs with existing where constraints are not supported yet",
                "Move NG schema bounds to a manual extension or remove the existing constraints."
            )
            return input
        }
        let names = ngSchemaGenericParameterList(declaration)
        genericParameters = "<${names}>"
        genericConstraints = " where ${ngSchemaGenericBounds(declaration)}"
    }
    let typeName = declaration.identifier.value
    let concreteType = "${typeName}${genericParameters}"
    var fields = ""
    var count = 0i64
    for (member in declaration.body.decls) {
        let variable = match (member as VarDecl) {
            case Some(value) => value
            case None => continue
        }
        if (variable.isConst() || ngHasModifier(variable, "static")) {
            continue
        }
        if (count > 0i64) {
            fields += ",\n"
        }
        fields += "            NamedValue(\"${variable.identifier.value}\", ${ngSchemaExpression(variable.declType)})"
        count++
    }
    let generated = """
extend${genericParameters} ${concreteType} <: PostcardSchemaNg<${concreteType}>${genericConstraints} {
    public static func schemaNg(): NamedType {
        return structSchema("${typeName}", [
${fields}
        ])
    }
}
"""
    return input + cangjieLex("\n" + generated, true)
}

private func generateNgEnum(input: Tokens, declaration: EnumDecl): Tokens {
    if (declaration.isGenericDecl || declaration.ellipsis.value == "...") {
        diagReport(
            DiagReportLevel.ERROR,
            input,
            "@PostcardSchemaNg requires a non-generic exhaustive enum",
            "Use a non-generic payload wrapper or implement PostcardSchemaNg manually."
        )
        return input
    }
    let typeName = declaration.identifier.value
    var variants = ""
    var index = 0i64
    for (constructor in declaration.constructors) {
        if (index > 0i64) {
            variants += ",\n"
        }
        let name = constructor.identifier.value
        let arity = constructor.typeArguments.size
        if (arity == 0i64) {
            variants += "            NamedVariant(\"${name}\", DataModelVariant.UnitVariant)"
        } else if (arity == 1i64) {
            variants += "            NamedVariant(\"${name}\", DataModelVariant.NewtypeVariant(${ngSchemaExpression(constructor.typeArguments[0])}))"
        } else {
            var elements = ""
            var argumentIndex = 0i64
            while (argumentIndex < arity) {
                if (argumentIndex > 0i64) {
                    elements += ", "
                }
                elements += ngSchemaExpression(constructor.typeArguments[argumentIndex])
                argumentIndex++
            }
            variants += "            NamedVariant(\"${name}\", DataModelVariant.TupleVariant([${elements}]))"
        }
        index++
    }
    let generated = """
extend ${typeName} <: PostcardSchemaNg<${typeName}> {
    public static func schemaNg(): NamedType {
        return enumSchema("${typeName}", [
${variants}
        ])
    }
}
"""
    return input + cangjieLex("\n" + generated, true)
}

/** NG schema derive entry point corresponding to postcard-derive-ng. */
public macro PostcardSchemaNg(input: Tokens): Tokens {
    let declaration = parseDecl(input)
    match (declaration as StructDecl) {
        case Some(value) => return generateNgStruct(input, value)
        case None => ()
    }
    match (declaration as EnumDecl) {
        case Some(value) => return generateNgEnum(input, value)
        case None => ()
    }
    diagReport(
        DiagReportLevel.ERROR,
        input,
        "@PostcardSchemaNg can only be applied to a struct or enum",
        "Move the annotation before a declaration."
    )
    return input
}

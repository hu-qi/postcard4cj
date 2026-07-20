macro package postcard4cj.derive_ng

import std.ast.*

private func ngMaxPrimitive(typeName: String): String {
    return match (typeName) {
        case "UInt8" => "uint8MaxSize()"
        case "UInt16" => "uint16MaxSize()"
        case "UInt32" => "uint32MaxSize()"
        case "UInt64" => "uint64MaxSize()"
        case "Int8" => "int8MaxSize()"
        case "Int16" => "int16MaxSize()"
        case "Int32" => "int32MaxSize()"
        case "Int64" => "int64MaxSize()"
        case "Float32" => "float32MaxSize()"
        case "Float64" => "float64MaxSize()"
        case "Bool" => "boolMaxSize()"
        case "Rune" => "runeMaxSize()"
        case "Unit" => "unitMaxSize()"
        case "PostcardUInt128" => "uint128MaxSize()"
        case "PostcardInt128" => "int128MaxSize()"
        case _ => ""
    }
}

private func ngMaxExpression(typeNode: TypeNode): String {
    let rendered = typeNode.toTokens().toString()
    let primitive = ngMaxPrimitive(rendered)
    if (primitive.size > 0) {
        return primitive
    }
    if (rendered == "String" || rendered == "BigInt") {
        diagReport(
            DiagReportLevel.ERROR,
            typeNode.toTokens(),
            "@PostcardMaxSizeNg cannot determine a finite maximum for '${rendered}'",
            "Use a fixed-capacity wrapper or a manual PostcardMaxSize implementation."
        )
        return "0i64"
    }
    let reference = match (typeNode as RefType) {
        case Some(value) => value
        case None => return "${rendered}.postcardMaxSize()"
    }
    let identifier = reference.identifier.value
    if (identifier == "Array") {
        diagReport(
            DiagReportLevel.ERROR,
            typeNode.toTokens(),
            "@PostcardMaxSizeNg cannot bound Array<T>",
            "Use a fixed-capacity wrapper."
        )
        return "0i64"
    }
    if (identifier == "Option") {
        if (reference.typeArguments.size != 1) {
            return "0i64"
        }
        return "1i64 + ${ngMaxExpression(reference.typeArguments[0])}"
    }
    return "${rendered}.postcardMaxSize()"
}

private func ngMaxHasModifier(declaration: Decl, modifierName: String): Bool {
    for (modifier in declaration.modifiers) {
        if (modifier.keyword.value == modifierName) {
            return true
        }
    }
    return false
}

private func ngMaxGenericParameterList(declaration: Decl): String {
    return declaration.genericParam.parameters.toString()
}

private func ngMaxGenericBounds(declaration: Decl): String {
    var bounds = ""
    var first = true
    for (token in declaration.genericParam.parameters) {
        if (token.kind != TokenKind.IDENTIFIER) { continue }
        let name = token.value
        if (!first) { bounds += ", " }
        bounds += "${name} <: PostcardMaxSize"
        first = false
    }
    return bounds
}

private func ngMaxDiscriminantBytes(variantCount: Int64): Int64 {
    var value = UInt64(variantCount)
    var bytes = 1i64
    while (value >= 0x80u64) {
        value >>= 7
        bytes++
    }
    return bytes
}

private func generateNgMaxStruct(input: Tokens, declaration: StructDecl): Tokens {
    var genericParameters = ""
    var genericConstraints = ""
    if (declaration.isGenericDecl) {
        if (declaration.genericConstraint.size > 0) {
            diagReport(
                DiagReportLevel.ERROR,
                input,
                "@PostcardMaxSizeNg generic structs with existing where constraints are not supported yet",
                "Move maximum-size bounds to a manual extension or remove the existing constraints."
            )
            return input
        }
        let names = ngMaxGenericParameterList(declaration)
        genericParameters = "<${names}>"
        genericConstraints = " where ${ngMaxGenericBounds(declaration)}"
    }
    let typeName = declaration.identifier.value
    let concreteType = "${typeName}${genericParameters}"
    var expression = "0i64"
    for (member in declaration.body.decls) {
        let variable = match (member as VarDecl) {
            case Some(value) => value
            case None => continue
        }
        if (variable.isConst() || ngMaxHasModifier(variable, "static")) {
            continue
        }
        expression += " + ${ngMaxExpression(variable.declType)}"
    }
    let generated = """
extend${genericParameters} ${concreteType} <: PostcardMaxSize${genericConstraints} {
    public static func postcardMaxSize(): Int64 {
        return ${expression}
    }
}
"""
    return input + cangjieLex("\n" + generated, true)
}

private func generateNgMaxEnum(input: Tokens, declaration: EnumDecl): Tokens {
    if (declaration.isGenericDecl || declaration.ellipsis.value == "...") {
        diagReport(
            DiagReportLevel.ERROR,
            input,
            "@PostcardMaxSizeNg requires a non-generic exhaustive enum",
            "Use a non-generic payload wrapper or implement PostcardMaxSize manually."
        )
        return input
    }
    let typeName = declaration.identifier.value
    let discriminant = ngMaxDiscriminantBytes(declaration.constructors.size)
    var body = "        var maximumPayload = 0i64\n"
    var index = 0i64
    for (constructor in declaration.constructors) {
        var payload = "0i64"
        for (argument in constructor.typeArguments) {
            payload += " + ${ngMaxExpression(argument)}"
        }
        body += "        let payload${index} = ${payload}\n"
        body += "        if (payload${index} > maximumPayload) { maximumPayload = payload${index} }\n"
        index++
    }
    let generated = """
extend ${typeName} <: PostcardMaxSize {
    public static func postcardMaxSize(): Int64 {
${body}        return ${discriminant}i64 + maximumPayload
    }
}
"""
    return input + cangjieLex("\n" + generated, true)
}

/** NG MaxSize derive entry point corresponding to postcard-derive-ng. */
public macro PostcardMaxSizeNg(input: Tokens): Tokens {
    let declaration = parseDecl(input)
    match (declaration as StructDecl) {
        case Some(value) => return generateNgMaxStruct(input, value)
        case None => ()
    }
    match (declaration as EnumDecl) {
        case Some(value) => return generateNgMaxEnum(input, value)
        case None => ()
    }
    diagReport(
        DiagReportLevel.ERROR,
        input,
        "@PostcardMaxSizeNg can only be applied to a struct or enum",
        "Move the annotation before a declaration."
    )
    return input
}

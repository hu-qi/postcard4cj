macro package postcard4cj.postcard_macro

import std.ast.*

private func maxSizePrimitive(typeName: String): String {
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

private func maxSizeReportUnbounded(typeNode: TypeNode): Unit {
    let rendered = typeNode.toTokens().toString()
    diagReport(
        DiagReportLevel.ERROR,
        typeNode.toTokens(),
        "@PostcardMaxSize cannot determine a finite maximum for '${rendered}'",
        "Use a fixed-capacity wrapper implementing PostcardMaxSize or implement the bound manually."
    )
}

private func maxSizeExpression(typeNode: TypeNode): String {
    let rendered = typeNode.toTokens().toString()
    let primitive = maxSizePrimitive(rendered)
    if (primitive.size > 0) {
        return primitive
    }

    if (rendered == "String" || rendered == "BigInt") {
        maxSizeReportUnbounded(typeNode)
        return "0i64"
    }

    let reference = match (typeNode as RefType) {
        case Some(value) => value
        case None => return "${rendered}.postcardMaxSize()"
    }

    let identifier = reference.identifier.value
    if (identifier == "Array") {
        maxSizeReportUnbounded(typeNode)
        return "0i64"
    }
    if (identifier == "Option") {
        if (reference.typeArguments.size != 1) {
            maxSizeReportUnbounded(typeNode)
            return "0i64"
        }
        return "1i64 + ${maxSizeExpression(reference.typeArguments[0])}"
    }

    return "${rendered}.postcardMaxSize()"
}

private func maxSizeHasModifier(declaration: Decl, modifierName: String): Bool {
    for (modifier in declaration.modifiers) {
        if (modifier.keyword.value == modifierName) {
            return true
        }
    }
    return false
}

private func maxSizeStructExpression(declaration: StructDecl): String {
    var expression = "0i64"
    for (member in declaration.body.decls) {
        let variable = match (member as VarDecl) {
            case Some(value) => value
            case None => continue
        }
        if (variable.isConst() || maxSizeHasModifier(variable, "static")) {
            continue
        }
        expression += " + ${maxSizeExpression(variable.declType)}"
    }
    return expression
}

private func maxSizeDiscriminantBytes(variantCount: Int64): Int64 {
    var value = UInt64(variantCount)
    var bytes = 1i64
    while (value >= 0x80u64) {
        value >>= 7
        bytes++
    }
    return bytes
}

private func generateStructMaxSize(input: Tokens, declaration: StructDecl): Tokens {
    if (declaration.isGenericDecl) {
        diagReport(
            DiagReportLevel.ERROR,
            input,
            "@PostcardMaxSize generic structs are not supported yet",
            "Implement PostcardMaxSize manually until generic macro bounds are available."
        )
        return input
    }

    let typeName = declaration.identifier.value
    let expression = maxSizeStructExpression(declaration)
    let generated = """
extend ${typeName} <: PostcardMaxSize {
    public static func postcardMaxSize(): Int64 {
        return ${expression}
    }
}
"""
    return input + cangjieLex("\n" + generated, true)
}

private func generateEnumMaxSize(input: Tokens, declaration: EnumDecl): Tokens {
    if (declaration.isGenericDecl) {
        diagReport(
            DiagReportLevel.ERROR,
            input,
            "@PostcardMaxSize generic enums are not supported yet",
            "Implement PostcardMaxSize manually until generic macro bounds are available."
        )
        return input
    }
    if (declaration.ellipsis.value == "...") {
        diagReport(
            DiagReportLevel.ERROR,
            input,
            "@PostcardMaxSize cannot bound a non-exhaustive enum",
            "Remove the ellipsis constructor or implement the bound manually."
        )
        return input
    }

    let typeName = declaration.identifier.value
    let variantCount = declaration.constructors.size
    let discriminantBytes = maxSizeDiscriminantBytes(variantCount)
    var payloadBody = "        var maximumPayload = 0i64\n"
    var variantIndex = 0i64

    for (constructor in declaration.constructors) {
        var payloadExpression = "0i64"
        for (argumentType in constructor.typeArguments) {
            payloadExpression += " + ${maxSizeExpression(argumentType)}"
        }
        payloadBody += "        let payload${variantIndex} = ${payloadExpression}\n"
        payloadBody += "        if (payload${variantIndex} > maximumPayload) { maximumPayload = payload${variantIndex} }\n"
        variantIndex++
    }

    let generated = """
extend ${typeName} <: PostcardMaxSize {
    public static func postcardMaxSize(): Int64 {
${payloadBody}        return ${discriminantBytes}i64 + maximumPayload
    }
}
"""
    return input + cangjieLex("\n" + generated, true)
}

/** Generate the maximum unflavored Postcard size for a struct or enum. */
public macro PostcardMaxSize(input: Tokens): Tokens {
    let declaration = parseDecl(input)
    match (declaration as StructDecl) {
        case Some(value) => return generateStructMaxSize(input, value)
        case None => ()
    }
    match (declaration as EnumDecl) {
        case Some(value) => return generateEnumMaxSize(input, value)
        case None => ()
    }
    diagReport(
        DiagReportLevel.ERROR,
        input,
        "@PostcardMaxSize can only be applied to a struct or enum",
        "Move the annotation directly before a struct or enum declaration."
    )
    return input
}

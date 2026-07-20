macro package postcard4cj.postcard_macro

import std.ast.*

private func primitiveEncoder(typeName: String): String {
    return match (typeName) {
        case "UInt8" => "writeUInt8"
        case "UInt16" => "writeUInt16"
        case "UInt32" => "writeUInt32"
        case "UInt64" => "writeUInt64"
        case "Int8" => "writeInt8"
        case "Int16" => "writeInt16"
        case "Int32" => "writeInt32"
        case "Int64" => "writeInt64"
        case "Float32" => "writeFloat32"
        case "Float64" => "writeFloat64"
        case "Bool" => "writeBool"
        case "String" => "writeString"
        case "Rune" => "writeRune"
        case "Unit" => "writeUnit"
        case _ => ""
    }
}

private func primitiveDecoder(typeName: String): String {
    return match (typeName) {
        case "UInt8" => "readUInt8"
        case "UInt16" => "readUInt16"
        case "UInt32" => "readUInt32"
        case "UInt64" => "readUInt64"
        case "Int8" => "readInt8"
        case "Int16" => "readInt16"
        case "Int32" => "readInt32"
        case "Int64" => "readInt64"
        case "Float32" => "readFloat32"
        case "Float64" => "readFloat64"
        case "Bool" => "readBool"
        case "String" => "readString"
        case "Rune" => "readRune"
        case "Unit" => "readUnit"
        case _ => ""
    }
}

private func hasModifier(declaration: Decl, modifierName: String): Bool {
    for (modifier in declaration.modifiers) {
        if (modifier.keyword.value == modifierName) { return true }
    }
    return false
}

private func reportUnsupported(typeNode: TypeNode): Unit {
    let rendered = typeNode.toTokens().toString()
    diagReport(DiagReportLevel.ERROR,typeNode.toTokens(),"@Postcard does not yet support field type '${rendered}'","Implement the codec manually or use a primitive, Option<T>, Array<T>, a generic codec parameter, or a nested codec type.")
}

private func encodeStatement(typeNode: TypeNode, valueExpr: String): String {
    let rendered = typeNode.toTokens().toString()
    let primitive = primitiveEncoder(rendered)
    if (primitive.size > 0) { return "encoder.${primitive}(${valueExpr})" }
    let reference = match (typeNode as RefType) {
        case Some(value) => value
        case None => reportUnsupported(typeNode); return "encoder.writeUnit()"
    }
    let identifier = reference.identifier.value
    if (identifier == "BigInt") {
        diagReport(DiagReportLevel.ERROR,typeNode.toTokens(),"@Postcard cannot infer whether BigInt represents signed or unsigned 128-bit data","Use PostcardInt128/PostcardUInt128 or implement the codec manually.")
        return "encoder.writeUnit()"
    }
    if (identifier == "Option" || identifier == "Array") {
        if (reference.typeArguments.size != 1) { reportUnsupported(typeNode); return "encoder.writeUnit()" }
        let inner = reference.typeArguments[0]
        let innerType = inner.toTokens().toString()
        let innerStatement = encodeStatement(inner,"value")
        if (identifier == "Option") { return "encoder.writeOption<${innerType}>(${valueExpr}, {value: ${innerType} => ${innerStatement}})" }
        return "encoder.writeSequence<${innerType}>(${valueExpr}, {value: ${innerType} => ${innerStatement}})"
    }
    return "${valueExpr}.encode(encoder)"
}

private func decodeExpression(typeNode: TypeNode): String {
    let rendered = typeNode.toTokens().toString()
    let primitive = primitiveDecoder(rendered)
    if (primitive.size > 0) { return "decoder.${primitive}()" }
    let reference = match (typeNode as RefType) {
        case Some(value) => value
        case None => reportUnsupported(typeNode); return "decoder.readUnit()"
    }
    let identifier = reference.identifier.value
    if (identifier == "BigInt") {
        diagReport(DiagReportLevel.ERROR,typeNode.toTokens(),"@Postcard cannot infer whether BigInt represents signed or unsigned 128-bit data","Use PostcardInt128/PostcardUInt128 or implement the codec manually.")
        return "decoder.readUnit()"
    }
    if (identifier == "Option" || identifier == "Array") {
        if (reference.typeArguments.size != 1) { reportUnsupported(typeNode); return "decoder.readUnit()" }
        let inner = reference.typeArguments[0]
        let innerType = inner.toTokens().toString()
        let innerExpression = decodeExpression(inner)
        if (identifier == "Option") { return "decoder.readOption<${innerType}>({=> ${innerExpression}})" }
        return "decoder.readSequence<${innerType}>({=> ${innerExpression}})"
    }
    return "${rendered}.decode(decoder)"
}

private func genericParameterList(declaration: Decl): String {
    return declaration.genericParam.parameters.toString()
}

private func genericCodecBounds(declaration: Decl): String {
    var bounds = ""
    var first = true
    for (token in declaration.genericParam.parameters) {
        let name = token.value
        if (name.size == 0 || name == "," || name == "\n") { continue }
        if (!first) { bounds += ", " }
        bounds += "${name} <: PostcardEncode & PostcardDecode<${name}>"
        first = false
    }
    return bounds
}

private func generateStruct(input: Tokens, declaration: StructDecl): Tokens {
    var genericParameters = ""
    var genericConstraints = ""
    if (declaration.isGenericDecl) {
        if (declaration.genericConstraint.size > 0) {
            diagReport(DiagReportLevel.ERROR,input,"@Postcard generic structs with existing where constraints are not supported yet","Move the codec bounds to a manual extension or remove the existing constraints.")
            return input
        }
        let names = genericParameterList(declaration)
        genericParameters = "<${names}>"
        genericConstraints = " where ${genericCodecBounds(declaration)}"
    }

    let typeName = declaration.identifier.value
    let concreteType = "${typeName}${genericParameters}"
    var encodeBody = ""
    var decodeArguments = ""
    var fieldCount = 0i64
    for (member in declaration.body.decls) {
        let variable = match (member as VarDecl) { case Some(value) => value; case None => continue }
        if (variable.isConst() || hasModifier(variable,"static")) { continue }
        let fieldName = variable.identifier.value
        if (fieldName.size == 0) {
            diagReport(DiagReportLevel.ERROR,variable.toTokens(),"@Postcard only supports simple named struct fields","Replace destructuring declarations with one named field per declaration.")
            continue
        }
        if (hasModifier(variable,"private")) {
            diagReport(DiagReportLevel.ERROR,variable.toTokens(),"@Postcard cannot access private field '${fieldName}' from its generated extension","Use internal/public/protected visibility or implement the codec inside the struct manually.")
            continue
        }
        encodeBody += "        ${encodeStatement(variable.declType, "this.${fieldName}")}\n"
        if (fieldCount > 0i64) { decodeArguments += ",\n" }
        decodeArguments += "            ${decodeExpression(variable.declType)}"
        fieldCount++
    }
    let generated = """
extend${genericParameters} ${concreteType} <: PostcardEncode & PostcardDecode<${concreteType}>${genericConstraints} {
    public func encode(encoder: PostcardEncoder): Unit {
${encodeBody}    }

    public static func decode(decoder: PostcardDecoder): ${concreteType} {
        return ${concreteType}(
${decodeArguments}
        )
    }
}
"""
    return input + cangjieLex("\n" + generated,true)
}

private func generateEnum(input: Tokens, declaration: EnumDecl): Tokens {
    if (declaration.isGenericDecl) {
        diagReport(DiagReportLevel.ERROR,input,"@Postcard generic enums are not supported yet","Use a non-generic enum payload wrapper or implement PostcardEncode/PostcardDecode manually.")
        return input
    }
    if (declaration.ellipsis.value == "...") {
        diagReport(DiagReportLevel.ERROR,input,"@Postcard cannot generate a stable codec for a non-exhaustive enum","Remove the ellipsis constructor or implement the codec manually.")
        return input
    }
    let typeName = declaration.identifier.value
    var encodeCases = ""
    var decodeCases = ""
    var variantIndex = 0i64
    for (constructor in declaration.constructors) {
        let constructorName = constructor.identifier.value
        let argumentCount = constructor.typeArguments.size
        var patternArguments = ""
        var encodePayload = ""
        var decodeArguments = ""
        var argumentIndex = 0i64
        while (argumentIndex < argumentCount) {
            if (argumentIndex > 0i64) { patternArguments += ", "; decodeArguments += ", " }
            let argumentName = "value${argumentIndex}"
            let argumentType = constructor.typeArguments[argumentIndex]
            patternArguments += argumentName
            encodePayload += "                ${encodeStatement(argumentType, argumentName)}\n"
            decodeArguments += decodeExpression(argumentType)
            argumentIndex++
        }
        if (argumentCount == 0i64) {
            encodeCases += "            case ${typeName}.${constructorName} =>\n                encoder.writeEnumIndex(${variantIndex}u32)\n"
            decodeCases += "            case ${variantIndex}u32 => ${typeName}.${constructorName}\n"
        } else {
            encodeCases += "            case ${typeName}.${constructorName}(${patternArguments}) =>\n                encoder.writeEnumIndex(${variantIndex}u32)\n"
            encodeCases += encodePayload
            decodeCases += "            case ${variantIndex}u32 => ${typeName}.${constructorName}(${decodeArguments})\n"
        }
        variantIndex++
    }
    let generated = """
extend ${typeName} <: PostcardEncode & PostcardDecode<${typeName}> {
    public func encode(encoder: PostcardEncoder): Unit {
        match (this) {
${encodeCases}        }
    }

    public static func decode(decoder: PostcardDecoder): ${typeName} {
        let variantIndex = decoder.readEnumIndex()
        return match (variantIndex) {
${decodeCases}            case _ => throw IllegalArgumentException("Unknown Postcard enum variant index for ${typeName}")
        }
    }
}
"""
    return input + cangjieLex("\n" + generated,true)
}

public macro Postcard(input: Tokens): Tokens {
    let declaration = parseDecl(input)
    match (declaration as StructDecl) { case Some(value) => return generateStruct(input,value); case None => () }
    match (declaration as EnumDecl) { case Some(value) => return generateEnum(input,value); case None => () }
    diagReport(DiagReportLevel.ERROR,input,"@Postcard can only be applied to a struct or enum declaration","Move the annotation directly before a struct or enum.")
    return input
}

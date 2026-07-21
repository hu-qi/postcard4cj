macro package postcard4cj.derive_ng

import std.ast.*
import std.collection.*

private func ngRenameArguments(attributes: Tokens): Array<String> {
    let values = ArrayList<String>()
    for (token in attributes) {
        if (token.kind == TokenKind.STRING_LITERAL) {
            values.add(token.value)
        } else if (token.value != ",") {
            throw IllegalArgumentException(
                "NG Schema rename attributes accept only comma-separated string literals."
            )
        }
    }
    return values.toArray()
}

private class NgSchemaRenameConfig {
    let typeName: String
    private let names: HashMap<String, String>

    init(attributes: Tokens, defaultTypeName: String) {
        names = HashMap<String, String>()
        let arguments = ngRenameArguments(attributes)
        if (arguments.size == 0) {
            typeName = defaultTypeName
            return
        }
        typeName = arguments[0]
        for (mapping in arguments[1..]) {
            let separator = mapping.indexOf("=") ?? -1
            if (separator <= 0 || separator >= mapping.size - 1) {
                throw IllegalArgumentException(
                    "NG Schema rename mapping '${mapping}' must use 'source=target'."
                )
            }
            names[mapping[..separator]] = mapping[separator + 1..]
        }
    }

    func nameFor(source: String): String {
        return names.get(source) ?? source
    }
}

private func ngNamedSchemaPrimitive(typeName: String): String {
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

private func ngNamedSchemaExpression(typeNode: TypeNode): String {
    let rendered = typeNode.toTokens().toString()
    let primitive = ngNamedSchemaPrimitive(rendered)
    if (primitive.size > 0) { return primitive }
    let reference = match (typeNode as RefType) {
        case Some(value) => value
        case None => return "${rendered}.schemaNg()"
    }
    let identifier = reference.identifier.value
    if (identifier == "Option" || identifier == "Array") {
        if (reference.typeArguments.size != 1) {
            throw IllegalArgumentException("NG Schema container '${rendered}' must have one type argument.")
        }
        let inner = ngNamedSchemaExpression(reference.typeArguments[0])
        return if (identifier == "Option") {
            "optionSchema(${inner})"
        } else {
            "sequenceSchema(${inner})"
        }
    }
    return "${rendered}.schemaNg()"
}

private func ngNamedHasModifier(declaration: Decl, modifierName: String): Bool {
    for (modifier in declaration.modifiers) {
        if (modifier.keyword.value == modifierName) { return true }
    }
    return false
}

private func generateNgNamedStruct(input: Tokens, declaration: StructDecl, config: NgSchemaRenameConfig): Tokens {
    var genericParameters = ""
    var genericConstraints = ""
    if (declaration.isGenericDecl) {
        genericParameters = "<${ngGenericParameterNames(declaration)}>"
        genericConstraints = ngMergedGenericConstraintClause(declaration, NgGenericBoundKind.Schema)
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
        if (variable.isConst() || ngNamedHasModifier(variable, "static")) { continue }
        if (count > 0) { fields += ",\n" }
        let sourceName = variable.identifier.value
        fields += "            NamedValue(\"${config.nameFor(sourceName)}\", ${ngNamedSchemaExpression(variable.declType)})"
        count++
    }
    let generated = """
extend${genericParameters} ${concreteType} <: PostcardSchemaNg<${concreteType}>${genericConstraints} {
    public static func schemaNg(): NamedType {
        return structSchema("${config.typeName}", [
${fields}
        ])
    }
}
"""
    return input + cangjieLex("\n" + generated, true)
}

private func generateNgNamedEnum(input: Tokens, declaration: EnumDecl, config: NgSchemaRenameConfig): Tokens {
    if (declaration.ellipsis.value == "...") {
        throw IllegalArgumentException("Named NG Schema cannot be generated for a non-exhaustive enum.")
    }
    var genericParameters = ""
    var genericConstraints = ""
    if (declaration.isGenericDecl) {
        genericParameters = "<${ngGenericParameterNames(declaration)}>"
        genericConstraints = ngMergedGenericConstraintClause(declaration, NgGenericBoundKind.Schema)
    }
    let typeName = declaration.identifier.value
    let concreteType = "${typeName}${genericParameters}"
    var variants = ""
    var index = 0i64
    for (constructor in declaration.constructors) {
        if (index > 0) { variants += ",\n" }
        let sourceName = constructor.identifier.value
        let displayName = config.nameFor(sourceName)
        let arity = constructor.typeArguments.size
        if (arity == 0) {
            variants += "            NamedVariant(\"${displayName}\", DataModelVariant.UnitVariant)"
        } else if (arity == 1) {
            variants += "            NamedVariant(\"${displayName}\", DataModelVariant.NewtypeVariant(${ngNamedSchemaExpression(constructor.typeArguments[0])}))"
        } else {
            var elements = ""
            for (argumentIndex in 0..arity) {
                if (argumentIndex > 0) { elements += ", " }
                elements += ngNamedSchemaExpression(constructor.typeArguments[argumentIndex])
            }
            variants += "            NamedVariant(\"${displayName}\", DataModelVariant.TupleVariant([${elements}]))"
        }
        index++
    }
    let generated = """
extend${genericParameters} ${concreteType} <: PostcardSchemaNg<${concreteType}>${genericConstraints} {
    public static func schemaNg(): NamedType {
        return enumSchema("${config.typeName}", [
${variants}
        ])
    }
}
"""
    return input + cangjieLex("\n" + generated, true)
}

/** Cangjie-native rename metadata for next-generation Postcard Schema. */
public macro PostcardSchemaNgNamed(attributes: Tokens, input: Tokens): Tokens {
    let declaration = parseDecl(input)
    let defaultName = match (declaration as StructDecl) {
        case Some(value) => value.identifier.value
        case None => match (declaration as EnumDecl) {
            case Some(value) => value.identifier.value
            case None => throw IllegalArgumentException("@PostcardSchemaNgNamed requires a struct or enum.")
        }
    }
    let config = NgSchemaRenameConfig(attributes, defaultName)
    match (declaration as StructDecl) {
        case Some(value) => return generateNgNamedStruct(input, value, config)
        case None => ()
    }
    match (declaration as EnumDecl) {
        case Some(value) => return generateNgNamedEnum(input, value, config)
        case None => throw IllegalArgumentException("@PostcardSchemaNgNamed requires a struct or enum.")
    }
}

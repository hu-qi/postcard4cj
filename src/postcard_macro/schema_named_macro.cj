macro package postcard4cj.postcard_macro

import std.ast.*
import std.collection.*

private class SchemaRenameConfig {
    let typeName: String
    private let names: HashMap<String, String>

    init(attributes: Tokens, defaultTypeName: String) {
        names = HashMap<String, String>()
        let arguments = parseCommaSeparatedExpressions(attributes)
        if (arguments.size == 0) {
            typeName = defaultTypeName
            return
        }

        typeName = readString(arguments[0], "type name")
        for (argument in arguments[1..]) {
            let mapping = readString(argument, "name mapping")
            let separator = mapping.indexOf("=") ?? -1
            if (separator <= 0 || separator >= mapping.size - 1) {
                throw MacroException(
                    "Schema rename mapping '${mapping}' must use 'source=target'."
                )
            }
            names[mapping[..separator]] = mapping[separator + 1..]
        }
    }

    private static func readString(expression: Expr, role: String): String {
        match (expression) {
            case literal: LitConstExpr =>
                if (literal.literal.kind != TokenKind.STRING_LITERAL) {
                    throw MacroException("Schema ${role} must be a string literal.")
                }
                return literal.literal.value
            case _ => throw MacroException("Schema ${role} must be a string literal.")
        }
    }

    func nameFor(source: String): String {
        return names.get(source) ?? source
    }
}

private func namedSchemaPrimitive(typeName: String): String {
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

private func namedSchemaExpression(typeNode: TypeNode): String {
    let rendered = typeNode.toTokens().toString()
    let primitive = namedSchemaPrimitive(rendered)
    if (primitive.size > 0) { return primitive }
    let reference = match (typeNode as RefType) {
        case Some(value) => value
        case None => return "${rendered}.schema()"
    }
    let identifier = reference.identifier.value
    if (identifier == "Option" || identifier == "Array") {
        if (reference.typeArguments.size != 1) {
            throw MacroException("Schema container '${rendered}' must have one type argument.")
        }
        let inner = namedSchemaExpression(reference.typeArguments[0])
        return if (identifier == "Option") {
            "optionSchema(${inner})"
        } else {
            "sequenceSchema(${inner})"
        }
    }
    return "${rendered}.schema()"
}

private func namedHasModifier(declaration: Decl, modifierName: String): Bool {
    for (modifier in declaration.modifiers) {
        if (modifier.keyword.value == modifierName) { return true }
    }
    return false
}

private func generateNamedStruct(
    input: Tokens,
    declaration: StructDecl,
    config: SchemaRenameConfig
): Tokens {
    var genericParameters = ""
    var genericConstraints = ""
    if (declaration.isGenericDecl) {
        genericParameters = "<${genericParameterNames(declaration)}>"
        genericConstraints = mergedGenericConstraintClause(declaration, GenericBoundKind.Schema)
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
        if (variable.isConst() || namedHasModifier(variable, "static")) { continue }
        if (count > 0) { fields += ",\n" }
        let sourceName = variable.identifier.value
        fields += "            NamedValue(\"${config.nameFor(sourceName)}\", ${namedSchemaExpression(variable.declType)})"
        count++
    }
    let generated = """
extend${genericParameters} ${concreteType} <: PostcardSchema<${concreteType}>${genericConstraints} {
    public static func schema(): NamedType {
        return structSchema("${config.typeName}", [
${fields}
        ])
    }
}
"""
    return input + cangjieLex("\n" + generated, true)
}

private func generateNamedEnum(
    input: Tokens,
    declaration: EnumDecl,
    config: SchemaRenameConfig
): Tokens {
    if (declaration.ellipsis.value == "...") {
        throw MacroException("Named Schema cannot be generated for a non-exhaustive enum.")
    }
    var genericParameters = ""
    var genericConstraints = ""
    if (declaration.isGenericDecl) {
        genericParameters = "<${genericParameterNames(declaration)}>"
        genericConstraints = mergedGenericConstraintClause(declaration, GenericBoundKind.Schema)
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
            variants += "            NamedVariant(\"${displayName}\", DataModelVariant.NewtypeVariant(${namedSchemaExpression(constructor.typeArguments[0])}))"
        } else {
            var elements = ""
            for (argumentIndex in 0..arity) {
                if (argumentIndex > 0) { elements += ", " }
                elements += namedSchemaExpression(constructor.typeArguments[argumentIndex])
            }
            variants += "            NamedVariant(\"${displayName}\", DataModelVariant.TupleVariant([${elements}]))"
        }
        index++
    }
    let generated = """
extend${genericParameters} ${concreteType} <: PostcardSchema<${concreteType}>${genericConstraints} {
    public static func schema(): NamedType {
        return enumSchema("${config.typeName}", [
${variants}
        ])
    }
}
"""
    return input + cangjieLex("\n" + generated, true)
}

/**
 * Cangjie-native equivalent of serde rename metadata for Postcard Schema.
 *
 * Example: `@PostcardSchemaNamed["WireRecord", "id=wire_id"]`.
 */
public macro PostcardSchemaNamed(attributes: Tokens, input: Tokens): Tokens {
    let declaration = parseDecl(input)
    let defaultName = match (declaration as StructDecl) {
        case Some(value) => value.identifier.value
        case None => match (declaration as EnumDecl) {
            case Some(value) => value.identifier.value
            case None => throw MacroException("@PostcardSchemaNamed requires a struct or enum.")
        }
    }
    let config = SchemaRenameConfig(attributes, defaultName)
    match (declaration as StructDecl) {
        case Some(value) => return generateNamedStruct(input, value, config)
        case None => ()
    }
    match (declaration as EnumDecl) {
        case Some(value) => return generateNamedEnum(input, value, config)
        case None => throw MacroException("@PostcardSchemaNamed requires a struct or enum.")
    }
}

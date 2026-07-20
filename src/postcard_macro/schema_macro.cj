macro package postcard4cj.postcard_macro

import std.ast.*

private func schemaPrimitive(typeName: String): String {
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

private func schemaReportUnsupported(typeNode: TypeNode): Unit {
    let rendered = typeNode.toTokens().toString()
    diagReport(
        DiagReportLevel.ERROR,
        typeNode.toTokens(),
        "@PostcardSchema does not support field type '${rendered}'",
        "Use a primitive, Option<T>, Array<T>, a generic schema parameter, or a type implementing PostcardSchema."
    )
}

private func schemaExpression(typeNode: TypeNode): String {
    let rendered = typeNode.toTokens().toString()
    let primitive = schemaPrimitive(rendered)
    if (primitive.size > 0) {
        return primitive
    }

    let reference = match (typeNode as RefType) {
        case Some(value) => value
        case None =>
            schemaReportUnsupported(typeNode)
            return "unitSchema()"
    }

    let identifier = reference.identifier.value
    if (identifier == "BigInt") {
        diagReport(
            DiagReportLevel.ERROR,
            typeNode.toTokens(),
            "@PostcardSchema cannot infer whether BigInt is signed or unsigned",
            "Use PostcardInt128 or PostcardUInt128."
        )
        return "unitSchema()"
    }

    if (identifier == "Option" || identifier == "Array") {
        if (reference.typeArguments.size != 1) {
            schemaReportUnsupported(typeNode)
            return "unitSchema()"
        }
        let inner = schemaExpression(reference.typeArguments[0])
        if (identifier == "Option") {
            return "optionSchema(${inner})"
        }
        return "sequenceSchema(${inner})"
    }

    return "${rendered}.schema()"
}

private func schemaHasModifier(declaration: Decl, modifierName: String): Bool {
    for (modifier in declaration.modifiers) {
        if (modifier.keyword.value == modifierName) {
            return true
        }
    }
    return false
}

private func schemaGenericParameterList(declaration: Decl): String {
    return declaration.genericParam.parameters.toString()
}

private func schemaGenericBounds(declaration: Decl): String {
    var bounds = ""
    var first = true
    for (token in declaration.genericParam.parameters) {
        let name = token.value
        if (name.size == 0 || name == "," || name == "\n") { continue }
        if (!first) { bounds += ", " }
        bounds += "${name} <: PostcardSchema<${name}>"
        first = false
    }
    return bounds
}

private func generateStructSchema(input: Tokens, declaration: StructDecl): Tokens {
    var genericParameters = ""
    var genericConstraints = ""
    if (declaration.isGenericDecl) {
        if (declaration.genericConstraint.size > 0) {
            diagReport(
                DiagReportLevel.ERROR,
                input,
                "@PostcardSchema generic structs with existing where constraints are not supported yet",
                "Move schema bounds to a manual extension or remove the existing constraints."
            )
            return input
        }
        let names = schemaGenericParameterList(declaration)
        genericParameters = "<${names}>"
        genericConstraints = " where ${schemaGenericBounds(declaration)}"
    }

    let typeName = declaration.identifier.value
    let concreteType = "${typeName}${genericParameters}"
    var fields = ""
    var fieldCount = 0i64

    for (member in declaration.body.decls) {
        let variable = match (member as VarDecl) {
            case Some(value) => value
            case None => continue
        }
        if (variable.isConst() || schemaHasModifier(variable, "static")) {
            continue
        }
        let fieldName = variable.identifier.value
        if (fieldName.size == 0) {
            diagReport(
                DiagReportLevel.ERROR,
                variable.toTokens(),
                "@PostcardSchema only supports simple named fields",
                "Replace destructuring declarations with named fields."
            )
            continue
        }
        if (fieldCount > 0i64) {
            fields += ",\n"
        }
        fields += "            NamedValue(\"${fieldName}\", ${schemaExpression(variable.declType)})"
        fieldCount++
    }

    let generated = """
extend${genericParameters} ${concreteType} <: PostcardSchema<${concreteType}>${genericConstraints} {
    public static func schema(): NamedType {
        return structSchema("${typeName}", [
${fields}
        ])
    }
}
"""
    return input + cangjieLex("\n" + generated, true)
}

private func generateEnumSchema(input: Tokens, declaration: EnumDecl): Tokens {
    if (declaration.isGenericDecl) {
        diagReport(
            DiagReportLevel.ERROR,
            input,
            "@PostcardSchema generic enums are not supported yet",
            "Use a non-generic payload wrapper or implement PostcardSchema manually."
        )
        return input
    }
    if (declaration.ellipsis.value == "...") {
        diagReport(
            DiagReportLevel.ERROR,
            input,
            "@PostcardSchema cannot generate a stable schema for a non-exhaustive enum",
            "Remove the ellipsis constructor or implement the schema manually."
        )
        return input
    }

    let typeName = declaration.identifier.value
    var variants = ""
    var variantIndex = 0i64

    for (constructor in declaration.constructors) {
        if (variantIndex > 0i64) {
            variants += ",\n"
        }
        let constructorName = constructor.identifier.value
        let argumentCount = constructor.typeArguments.size
        if (argumentCount == 0i64) {
            variants += "            NamedVariant(\"${constructorName}\", DataModelVariant.UnitVariant)"
        } else if (argumentCount == 1i64) {
            variants += "            NamedVariant(\"${constructorName}\", DataModelVariant.NewtypeVariant(${schemaExpression(constructor.typeArguments[0])}))"
        } else {
            var elements = ""
            var argumentIndex = 0i64
            while (argumentIndex < argumentCount) {
                if (argumentIndex > 0i64) {
                    elements += ", "
                }
                elements += schemaExpression(constructor.typeArguments[argumentIndex])
                argumentIndex++
            }
            variants += "            NamedVariant(\"${constructorName}\", DataModelVariant.TupleVariant([${elements}]))"
        }
        variantIndex++
    }

    let generated = """
extend ${typeName} <: PostcardSchema<${typeName}> {
    public static func schema(): NamedType {
        return enumSchema("${typeName}", [
${variants}
        ])
    }
}
"""
    return input + cangjieLex("\n" + generated, true)
}

/** Generate a PostcardSchema implementation from declaration order. */
public macro PostcardSchema(input: Tokens): Tokens {
    let declaration = parseDecl(input)
    match (declaration as StructDecl) {
        case Some(value) => return generateStructSchema(input, value)
        case None => ()
    }
    match (declaration as EnumDecl) {
        case Some(value) => return generateEnumSchema(input, value)
        case None => ()
    }
    diagReport(
        DiagReportLevel.ERROR,
        input,
        "@PostcardSchema can only be applied to a struct or enum",
        "Move the annotation directly before a struct or enum declaration."
    )
    return input
}

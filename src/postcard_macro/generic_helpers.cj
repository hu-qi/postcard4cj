macro package postcard4cj.postcard_macro

import std.ast.*

enum GenericBoundKind {
    | Codec
    | Schema
    | MaxSize
}

func genericParameterNames(declaration: Decl): String {
    var names = ""
    var first = true
    for (token in declaration.genericParam.parameters) {
        if (token.kind != TokenKind.IDENTIFIER) { continue }
        if (!first) { names += ", " }
        names += token.value
        first = false
    }
    return names
}

private func requiredGenericBounds(name: String, kind: GenericBoundKind): String {
    return match (kind) {
        case GenericBoundKind.Codec =>
            "PostcardEncode & PostcardDecode<${name}>"
        case GenericBoundKind.Schema =>
            "PostcardSchema<${name}>"
        case GenericBoundKind.MaxSize =>
            "PostcardMaxSize"
    }
}

private func declaredUpperBounds(declaration: Decl, name: String): String {
    for (constraint in declaration.genericConstraint) {
        if (constraint.typeArgument.toTokens().toString() != name) { continue }
        var bounds = ""
        var first = true
        for (upperBound in constraint.upperBounds) {
            if (!first) { bounds += " & " }
            bounds += upperBound.toTokens().toString()
            first = false
        }
        return bounds
    }
    return ""
}

func genericBoundList(declaration: Decl, kind: GenericBoundKind): String {
    var constraints = ""
    var firstConstraint = true
    for (token in declaration.genericParam.parameters) {
        if (token.kind != TokenKind.IDENTIFIER) { continue }
        let name = token.value
        if (!firstConstraint) { constraints += ", " }
        let declared = declaredUpperBounds(declaration, name)
        constraints += "${name} <: "
        if (declared.size > 0) {
            constraints += "${declared} & "
        }
        constraints += requiredGenericBounds(name, kind)
        firstConstraint = false
    }
    return constraints
}

/** Preserve the declaration's existing upper bounds and append macro-required bounds. */
func mergedGenericConstraintClause(declaration: Decl, kind: GenericBoundKind): String {
    return " where ${genericBoundList(declaration, kind)}"
}

macro package postcard4cj.derive_ng

import std.ast.*

enum NgGenericBoundKind {
    | Schema
    | MaxSize
}

func ngGenericParameterNames(declaration: Decl): String {
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

private func ngRequiredGenericBounds(name: String, kind: NgGenericBoundKind): String {
    return match (kind) {
        case NgGenericBoundKind.Schema =>
            "PostcardSchemaNg<${name}>"
        case NgGenericBoundKind.MaxSize =>
            "PostcardMaxSize"
    }
}

private func ngDeclaredUpperBounds(declaration: Decl, name: String): String {
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

func ngGenericBoundList(declaration: Decl, kind: NgGenericBoundKind): String {
    var constraints = ""
    var firstConstraint = true
    for (token in declaration.genericParam.parameters) {
        if (token.kind != TokenKind.IDENTIFIER) { continue }
        let name = token.value
        if (!firstConstraint) { constraints += ", " }
        let declared = ngDeclaredUpperBounds(declaration, name)
        constraints += "${name} <: "
        if (declared.size > 0) {
            constraints += "${declared} & "
        }
        constraints += ngRequiredGenericBounds(name, kind)
        firstConstraint = false
    }
    return constraints
}

/** Preserve the declaration's existing upper bounds and append NG-required bounds. */
func ngMergedGenericConstraintClause(declaration: Decl, kind: NgGenericBoundKind): String {
    return " where ${ngGenericBoundList(declaration, kind)}"
}

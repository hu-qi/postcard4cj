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

func ngGenericBoundList(declaration: Decl, kind: NgGenericBoundKind): String {
    var bounds = ""
    var first = true
    for (token in declaration.genericParam.parameters) {
        if (token.kind != TokenKind.IDENTIFIER) { continue }
        let name = token.value
        if (!first) { bounds += ", " }
        bounds += match (kind) {
            case NgGenericBoundKind.Schema =>
                "${name} <: PostcardSchemaNg<${name}>"
            case NgGenericBoundKind.MaxSize =>
                "${name} <: PostcardMaxSize"
        }
        first = false
    }
    return bounds
}

private func ngDeclaredGenericConstraintClause(declaration: Decl): String {
    var clause = ""
    for (index in 0..declaration.genericConstraint.size) {
        if (index > 0) { clause += ", " }
        clause += declaration.genericConstraint[index].toTokens().toString()
    }
    return clause
}

/** Preserve the declaration's existing constraints and append NG-required bounds. */
func ngMergedGenericConstraintClause(declaration: Decl, kind: NgGenericBoundKind): String {
    let generated = ngGenericBoundList(declaration, kind)
    let declared = ngDeclaredGenericConstraintClause(declaration)
    if (declared.size == 0) {
        return " where ${generated}"
    }
    return "${declared}, ${generated}"
}

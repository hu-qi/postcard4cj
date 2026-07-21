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

func genericBoundList(declaration: Decl, kind: GenericBoundKind): String {
    var bounds = ""
    var first = true
    for (token in declaration.genericParam.parameters) {
        if (token.kind != TokenKind.IDENTIFIER) { continue }
        let name = token.value
        if (!first) { bounds += ", " }
        bounds += match (kind) {
            case GenericBoundKind.Codec =>
                "${name} <: PostcardEncode & PostcardDecode<${name}>"
            case GenericBoundKind.Schema =>
                "${name} <: PostcardSchema<${name}>"
            case GenericBoundKind.MaxSize =>
                "${name} <: PostcardMaxSize"
        }
        first = false
    }
    return bounds
}

private func declaredGenericConstraintClause(declaration: Decl): String {
    var clause = ""
    for (index in 0..declaration.genericConstraint.size) {
        if (index > 0) { clause += ", " }
        clause += declaration.genericConstraint[index].toTokens().toString()
    }
    return clause
}

/** Preserve the declaration's existing constraints and append macro-required bounds. */
func mergedGenericConstraintClause(declaration: Decl, kind: GenericBoundKind): String {
    let generated = genericBoundList(declaration, kind)
    let declared = declaredGenericConstraintClause(declaration)
    if (declared.size == 0) {
        return " where ${generated}"
    }
    return "${declared}, ${generated}"
}

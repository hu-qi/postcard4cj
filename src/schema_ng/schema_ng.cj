package postcard4cj.schema_ng

import postcard4cj.schema.*

/** Next-generation schema interface corresponding to postcard-schema-ng. */
public interface PostcardSchemaNg<T> {
    static func schemaNg(): NamedType
}

public func schemaNgOf<T>(): NamedType where T <: PostcardSchemaNg<T> {
    return T.schemaNg()
}

/**
 * The upstream legacy and NG schema data models are wire-compatible. Cangjie
 * therefore reuses the validated runtime-owned NamedType tree while keeping a
 * distinct interface and derive namespace.
 */
public func toOwnedSchemaNg<T>(): NamedType where T <: PostcardSchemaNg<T> {
    return toOwnedSchema(T.schemaNg())
}

public func keyForPathNg<T>(path: String): Key where T <: PostcardSchemaNg<T> {
    return keyForSchemaPath(path, T.schemaNg())
}

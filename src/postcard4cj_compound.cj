package postcard4cj

import std.collection.*

extend PostcardEncoder {
    /** Unit values occupy zero bytes in the Postcard wire format. */
    public func writeUnit(): Unit {}

    /**
     * Writes one Unicode scalar value as a length-prefixed UTF-8 sequence.
     */
    public func writeRune(value: Rune): Unit {
        let length = Rune.utf8Size(value)
        let buffer = Array<UInt8>(length, repeat: 0u8)
        let written = Rune.intoUtf8Array(value, buffer, 0)
        if (written != length) {
            throw IllegalStateException("Rune UTF-8 encoding wrote an invalid length")
        }
        writeBytes(buffer)
    }

    /** Writes the zero-based variant index used by Serde enums. */
    public func writeEnumIndex(index: UInt32): Unit {
        writeUInt32(index)
    }

    /** Tuples have no length prefix; elements are written in schema order. */
    public func writeTuple2<A, B>(
        value: (A, B),
        writeFirst: (A) -> Unit,
        writeSecond: (B) -> Unit
    ): Unit {
        writeFirst(value[0])
        writeSecond(value[1])
    }

    /**
     * Writes map entries as an entry count followed by key/value pairs.
     *
     * Postcard does not define a canonical map order. Callers that require
     * deterministic output must pass entries in a deterministic order.
     */
    public func writeMapEntries<K, V>(
        entries: Array<(K, V)>,
        writeKey: (K) -> Unit,
        writeValue: (V) -> Unit
    ): Unit {
        writeSequenceLength(entries.size)
        for (entry in entries) {
            writeKey(entry[0])
            writeValue(entry[1])
        }
    }
}

extend PostcardDecoder {
    /** Reads a zero-byte Unit value. */
    public func readUnit(): Unit {
        return ()
    }

    /** Reads exactly one length-prefixed UTF-8 Unicode scalar value. */
    public func readRune(): Rune {
        let bytes = readBytes()
        if (bytes.size < 1 || bytes.size > 4) {
            throw IllegalArgumentException("Invalid Postcard Rune byte length")
        }

        let decoded = Rune.fromUtf8(bytes, 0)
        if (decoded[1] != bytes.size) {
            throw IllegalArgumentException("Postcard Rune contains more than one scalar value")
        }
        return decoded[0]
    }

    /** Reads the zero-based variant index used by Serde enums. */
    public func readEnumIndex(): UInt32 {
        return readUInt32()
    }

    /** Tuples have no length prefix; elements are read in schema order. */
    public func readTuple2<A, B>(readFirst: () -> A, readSecond: () -> B): (A, B) {
        return (readFirst(), readSecond())
    }

    /** Reads a map representation into an ordered entry array. */
    public func readMapEntries<K, V>(
        readKey: () -> K,
        readValue: () -> V
    ): Array<(K, V)> {
        let length = readSequenceLength()
        // Do not trust a wire-provided count as an eager allocation size.
        // ArrayList remains free to grow for legitimate zero-sized entries.
        let remainingBytes = remaining()
        let initialCapacity = if (length > remainingBytes) { remainingBytes } else { length }
        let output = ArrayList<(K, V)>(initialCapacity)
        var index = 0i64
        while (index < length) {
            output.add((readKey(), readValue()))
            index++
        }
        return output.toArray()
    }
}

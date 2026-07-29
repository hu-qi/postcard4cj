package postcard4cj.core

/**
 * Cangjie-native equivalent of the caller-supplied `crc::Digest<u32>` accepted
 * by upstream Postcard CRC APIs.
 */
public interface Crc32Digest {
    func updateByte(value: UInt8): Unit
    func checksum(): UInt32
    func fresh(): Crc32Digest
}

/** Complete width-32 CRC algorithm parameters. */
public class Crc32Algorithm {
    public let polynomial: UInt32
    public let initial: UInt32
    public let reflectInput: Bool
    public let reflectOutput: Bool
    public let xorOutput: UInt32

    public init(
        polynomial: UInt32,
        initial: UInt32,
        reflectInput: Bool,
        reflectOutput: Bool,
        xorOutput: UInt32
    ) {
        this.polynomial = polynomial
        this.initial = initial
        this.reflectInput = reflectInput
        this.reflectOutput = reflectOutput
        this.xorOutput = xorOutput
    }
}

private func reverseBits32(value: UInt32): UInt32 {
    var input = value
    var output = 0u32
    var bit = 0i64
    while (bit < 32) {
        output = (output << 1) | (input & 1u32)
        input >>= 1
        bit++
    }
    return output
}

/** Stateful digest for an arbitrary width-32 CRC algorithm. */
public class ConfigurableCrc32Digest <: Crc32Digest {
    private let algorithm: Crc32Algorithm
    private var state: UInt32

    public init(algorithm: Crc32Algorithm) {
        this.algorithm = algorithm
        state = algorithm.initial
    }

    public func updateByte(value: UInt8): Unit {
        if (algorithm.reflectInput) {
            state ^= UInt32(value)
            var bit = 0i64
            while (bit < 8) {
                state = if ((state & 1u32) != 0u32) {
                    (state >> 1) ^ algorithm.polynomial
                } else {
                    state >> 1
                }
                bit++
            }
        } else {
            state ^= UInt32(value) << 24
            var bit = 0i64
            while (bit < 8) {
                state = if ((state & 0x8000_0000u32) != 0u32) {
                    (state << 1) ^ algorithm.polynomial
                } else {
                    state << 1
                }
                bit++
            }
        }
    }

    public func checksum(): UInt32 {
        let finalized = if (algorithm.reflectInput == algorithm.reflectOutput) {
            state
        } else {
            reverseBits32(state)
        }
        return finalized ^ algorithm.xorOutput
    }

    public func fresh(): Crc32Digest {
        return ConfigurableCrc32Digest(algorithm)
    }
}

/** CRC-32/ISCSI (Castagnoli), matching the upstream Postcard example. */
public func crc32IscsiDigest(): Crc32Digest {
    return ConfigurableCrc32Digest(Crc32Algorithm(
        0x82f6_3b78u32,
        0xffff_ffffu32,
        true,
        true,
        0xffff_ffffu32
    ))
}

/** CRC-32/ISO-HDLC, useful for proving caller-selected digest behavior. */
public func crc32IsoHdlcDigest(): Crc32Digest {
    return ConfigurableCrc32Digest(Crc32Algorithm(
        0xedb8_8320u32,
        0xffff_ffffu32,
        true,
        true,
        0xffff_ffffu32
    ))
}

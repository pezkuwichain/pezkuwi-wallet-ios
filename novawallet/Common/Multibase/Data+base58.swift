import Foundation
import BigInt

extension Data {
    init?(base58btcEncoded input: String) {
        let alphabet = [UInt8]("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
        guard let data = Self.decodeBase58(input: input, alphabet: alphabet) else {
            return nil
        }
        self = data
    }

    init?(base58FlickrEncoded input: String) {
        let alphabet = [UInt8]("123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ".utf8)
        guard let data = Self.decodeBase58(input: input, alphabet: alphabet) else {
            return nil
        }
        self = data
    }

    static func decodeBase58(input: String, alphabet: [UInt8]) -> Data? {
        var answer = BigUInt(0)
        var idx = BigUInt(1)
        let byteString = [UInt8](input.utf8)

        for char in byteString.reversed() {
            guard let alphabetIndex = alphabet.firstIndex(of: char) else {
                return nil
            }
            answer += (idx * BigUInt(alphabetIndex))
            idx *= BigUInt(alphabet.count)
        }

        let bytes = answer.serialize()
        // For every leading one on the input we need to add a leading 0 on the output
        let leadingOnes = byteString.prefix(while: { value in value == alphabet[0] })
        let leadingZeros: [UInt8] = Array(repeating: 0, count: leadingOnes.count)
        return leadingZeros + bytes
    }

    static let base58btcAlphabet = [UInt8]("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)

    /// Encodes `self` as a Base58 string using the given alphabet (defaults to the standard
    /// Bitcoin/Tron "base58btc" alphabet). This is the encode-direction counterpart of
    /// `decodeBase58(input:alphabet:)` above, which only supported decoding.
    func base58EncodedString(alphabet: [UInt8] = Data.base58btcAlphabet) -> String {
        guard !isEmpty else {
            return ""
        }

        var value = BigUInt(self)
        let base = BigUInt(alphabet.count)

        var reversedEncodedBytes: [UInt8] = []

        while value > 0 {
            let (quotient, remainder) = value.quotientAndRemainder(dividingBy: base)
            reversedEncodedBytes.append(alphabet[Int(remainder)])
            value = quotient
        }

        // For every leading zero byte on the input we need to add a leading alphabet[0]
        // ("1" for base58btc) character on the output.
        let leadingZerosCount = prefix(while: { $0 == 0 }).count
        let leadingOnes = [UInt8](repeating: alphabet[0], count: leadingZerosCount)

        let encodedBytes = leadingOnes + reversedEncodedBytes.reversed()

        // Safe force-unwrap: every byte in `encodedBytes` comes from `alphabet`, which is
        // constructed from an ASCII Swift string literal, so this can never fail to decode as UTF-8.
        return String(bytes: encodedBytes, encoding: .utf8)!
    }
}

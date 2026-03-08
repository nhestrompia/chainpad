import Foundation

@MainActor
public final class RegexDetector: Detector {
    private let evmAddressPattern = /^0x[a-fA-F0-9]{40}$/
    private let evmTxPattern = /^0x[a-fA-F0-9]{64}$/
    private let base58Alphabet = CharacterSet(charactersIn: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

    public init() {}

    public func detect(_ text: String) -> DetectionResult? {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return nil }

        if let urlDetection = detectURL(normalized) {
            return urlDetection
        }

        if normalized.wholeMatch(of: evmAddressPattern) != nil {
            return DetectionResult(
                rawValue: text,
                normalizedValue: normalized.lowercased(),
                kind: .evmAddress,
                type: .wallet,
                chainHint: .unknown
            )
        }

        if normalized.wholeMatch(of: evmTxPattern) != nil {
            return DetectionResult(
                rawValue: text,
                normalizedValue: normalized.lowercased(),
                kind: .evmTransaction,
                type: .transaction,
                chainHint: .unknown
            )
        }

        if isPotentialSolanaAddress(normalized) {
            return DetectionResult(
                rawValue: text,
                normalizedValue: normalized,
                kind: .solanaAddress,
                type: .wallet,
                chainHint: .solana
            )
        }

        if isPotentialSolanaTransaction(normalized) {
            return DetectionResult(
                rawValue: text,
                normalizedValue: normalized,
                kind: .solanaTransaction,
                type: .transaction,
                chainHint: .solana
            )
        }

        return nil
    }

    private func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")
    }

    private func isPotentialSolanaAddress(_ value: String) -> Bool {
        guard (32...44).contains(value.count) else { return false }
        return value.rangeOfCharacter(from: base58Alphabet.inverted) == nil
    }

    private func isPotentialSolanaTransaction(_ value: String) -> Bool {
        guard (70...120).contains(value.count) else { return false }
        return value.rangeOfCharacter(from: base58Alphabet.inverted) == nil
    }

    private func detectURL(_ value: String) -> DetectionResult? {
        guard let url = URL(string: value), let host = url.host()?.lowercased() else {
            return nil
        }

        if host.contains("dexscreener.com") || host.contains("birdeye.so") {
            return DetectionResult(
                rawValue: value,
                normalizedValue: value,
                kind: .pairURL,
                type: .pair,
                chainHint: chainHint(from: url)
            )
        }

        if host.contains("etherscan.io") || host.contains("arbiscan.io") || host.contains("basescan.org") || host.contains("bscscan.com") || host.contains("polygonscan.com") || host.contains("solscan.io") {
            let normalized = value
            let path = url.path.lowercased()
            if path.contains("/tx/") {
                return DetectionResult(
                    rawValue: value,
                    normalizedValue: normalized,
                    kind: .explorerURL,
                    type: .transaction,
                    chainHint: chainHint(from: url)
                )
            }

            if path.contains("/address/") || path.contains("/token/") {
                return DetectionResult(
                    rawValue: value,
                    normalizedValue: normalized,
                    kind: .explorerURL,
                    type: .explorerLink,
                    chainHint: chainHint(from: url)
                )
            }

            return DetectionResult(
                rawValue: value,
                normalizedValue: normalized,
                kind: .explorerURL,
                type: .explorerLink,
                chainHint: chainHint(from: url)
            )
        }

        return nil
    }

    private func chainHint(from url: URL) -> Chain {
        guard let host = url.host()?.lowercased() else {
            return .unknown
        }

        if host.contains("solscan") {
            return .solana
        }
        if host.contains("arbiscan") {
            return .arbitrum
        }
        if host.contains("basescan") {
            return .base
        }
        if host.contains("bscscan") {
            return .bsc
        }
        if host.contains("polygonscan") {
            return .polygon
        }
        if host.contains("etherscan") {
            return .ethereum
        }

        let path = url.path.lowercased()
        if path.contains("/solana") {
            return .solana
        }
        if path.contains("/base") {
            return .base
        }
        if path.contains("/bsc") {
            return .bsc
        }
        if path.contains("/arbitrum") {
            return .arbitrum
        }
        if path.contains("/polygon") {
            return .polygon
        }
        if path.contains("/ethereum") {
            return .ethereum
        }

        return .unknown
    }
}

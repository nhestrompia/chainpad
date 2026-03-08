import Foundation

@MainActor
public final class DefaultValidator: Validator {
    private let evmRegex = /^0x[a-fA-F0-9]{40}$/
    private let evmTxRegex = /^0x[a-fA-F0-9]{64}$/

    private let dexClient: DexScreenerClient
    private let evmClient: EVMRPCClient
    private let solanaClient: SolanaRPCClient

    public init(
        dexClient: DexScreenerClient = DexScreenerClient(),
        evmClient: EVMRPCClient = EVMRPCClient(),
        solanaClient: SolanaRPCClient = SolanaRPCClient()
    ) {
        self.dexClient = dexClient
        self.evmClient = evmClient
        self.solanaClient = solanaClient
    }

    public func validate(_ detection: DetectionResult) async -> ValidationResult {
        switch detection.kind {
        case .evmAddress:
            return await validateEVMAddress(detection)
        case .solanaAddress:
            return await validateSolanaAddress(detection)
        case .evmTransaction:
            return await validateEVMTransaction(detection)
        case .solanaTransaction:
            return await validateSolanaTransaction(detection)
        case .explorerURL:
            return ValidationResult(isValid: true, type: detection.type, chain: detection.chainHint)
        case .pairURL:
            return ValidationResult(isValid: true, type: .pair, chain: detection.chainHint)
        }
    }

    private func validateEVMAddress(_ detection: DetectionResult) async -> ValidationResult {
        guard detection.normalizedValue.wholeMatch(of: evmRegex) != nil else {
            return ValidationResult(isValid: false, type: .wallet, chain: .unknown)
        }

        if let tokenProfile = await dexClient.fetchTokenProfile(address: detection.normalizedValue) {
            return ValidationResult(isValid: true, type: .token, chain: tokenProfile.chain)
        }

        if detection.chainHint.isEVM {
            if let code = await evmClient.contractCode(address: detection.normalizedValue, chain: detection.chainHint) {
                let type: CryptoObjectType = isContractCode(code) ? .token : .wallet
                return ValidationResult(isValid: true, type: type, chain: detection.chainHint)
            }
        }

        for chain in Chain.allCases where chain.isEVM {
            if let code = await evmClient.contractCode(address: detection.normalizedValue, chain: chain) {
                let type: CryptoObjectType = isContractCode(code) ? .token : .wallet
                return ValidationResult(isValid: true, type: type, chain: chain)
            }
        }

        return ValidationResult(isValid: true, type: .wallet, chain: .unknown)
    }

    private func validateSolanaAddress(_ detection: DetectionResult) async -> ValidationResult {
        if await dexClient.fetchTokenProfile(address: detection.normalizedValue) != nil {
            return ValidationResult(isValid: true, type: .token, chain: .solana)
        }

        if await solanaClient.tokenProgramOwnedAccountExists(address: detection.normalizedValue) {
            return ValidationResult(isValid: true, type: .token, chain: .solana)
        }

        let isValid = await solanaClient.addressLooksValid(detection.normalizedValue)
        guard isValid else {
            return ValidationResult(isValid: false, type: .wallet, chain: .solana)
        }

        return ValidationResult(isValid: true, type: .wallet, chain: .solana)
    }

    private func validateEVMTransaction(_ detection: DetectionResult) async -> ValidationResult {
        guard detection.normalizedValue.wholeMatch(of: evmTxRegex) != nil else {
            return ValidationResult(isValid: false, type: .transaction, chain: .unknown)
        }

        if detection.chainHint.isEVM {
            let exists = await evmClient.transactionExists(hash: detection.normalizedValue, chain: detection.chainHint)
            if exists {
                return ValidationResult(isValid: true, type: .transaction, chain: detection.chainHint)
            }
        }

        if let chain = await evmClient.chainWithTransaction(hash: detection.normalizedValue) {
            return ValidationResult(isValid: true, type: .transaction, chain: chain)
        }

        return ValidationResult(isValid: true, type: .transaction, chain: .unknown)
    }

    private func validateSolanaTransaction(_ detection: DetectionResult) async -> ValidationResult {
        let exists = await solanaClient.transactionExists(signature: detection.normalizedValue)
        if exists {
            return ValidationResult(isValid: true, type: .transaction, chain: .solana)
        }

        return ValidationResult(isValid: true, type: .transaction, chain: .solana)
    }

    private func isContractCode(_ code: String) -> Bool {
        let normalized = code.lowercased()
        return normalized != "0x" && normalized != "0x0"
    }
}

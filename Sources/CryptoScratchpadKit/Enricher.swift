import Foundation

@MainActor
public final class DefaultEnricher: Enricher {
    private let dexClient: DexScreenerClient
    private let evmClient: EVMRPCClient
    private let solanaClient: SolanaRPCClient
    private let quickActionBuilder: QuickActionBuilder

    public init(
        dexClient: DexScreenerClient = DexScreenerClient(),
        evmClient: EVMRPCClient = EVMRPCClient(),
        solanaClient: SolanaRPCClient = SolanaRPCClient(),
        quickActionBuilder: QuickActionBuilder
    ) {
        self.dexClient = dexClient
        self.evmClient = evmClient
        self.solanaClient = solanaClient
        self.quickActionBuilder = quickActionBuilder
    }

    public func enrich(_ object: CapturedObject) async -> EnrichmentResult {
        let defaultActions = quickActionBuilder.actions(for: object)

        switch object.type {
        case .token:
            return await enrichToken(object, defaultActions: defaultActions)
        case .wallet:
            return await enrichWallet(object, defaultActions: defaultActions)
        case .transaction:
            return await enrichTransaction(object, defaultActions: defaultActions)
        case .pair, .explorerLink:
            return EnrichmentResult(state: .partial, metadata: nil, quickActions: defaultActions)
        }
    }

    private func enrichToken(_ object: CapturedObject, defaultActions: [QuickActionLink]) async -> EnrichmentResult {
        if let profile = await dexClient.fetchTokenProfile(address: object.normalizedValue) {
            let token = TokenMetadata(
                name: profile.name,
                symbol: profile.symbol,
                priceUSD: profile.priceUSD,
                liquidityUSD: profile.liquidityUSD,
                marketCapUSD: profile.marketCapUSD,
                ageDays: profile.ageDays,
                imageURL: profile.imageURL,
                websiteURL: profile.websiteURL,
                twitterURL: profile.twitterURL,
                telegramURL: profile.telegramURL
            )
            return EnrichmentResult(state: .complete, metadata: MetadataEnvelope(token: token), quickActions: defaultActions)
        }

        return EnrichmentResult(state: .partial, metadata: MetadataEnvelope(token: TokenMetadata()), quickActions: defaultActions)
    }

    private func enrichWallet(_ object: CapturedObject, defaultActions: [QuickActionLink]) async -> EnrichmentResult {
        if object.chain == .solana {
            let balance = await solanaClient.balance(address: object.normalizedValue)
            let metadata = MetadataEnvelope(wallet: WalletMetadata(balance: balance, transactionCount: nil, label: nil))
            return EnrichmentResult(state: balance == nil ? .partial : .complete, metadata: metadata, quickActions: defaultActions)
        }

        if object.chain.isEVM {
            let balance = await evmClient.nativeBalance(address: object.normalizedValue, chain: object.chain)
            let metadata = MetadataEnvelope(wallet: WalletMetadata(balance: balance, transactionCount: nil, label: nil))
            return EnrichmentResult(state: balance == nil ? .partial : .complete, metadata: metadata, quickActions: defaultActions)
        }

        return EnrichmentResult(state: .partial, metadata: MetadataEnvelope(wallet: WalletMetadata()), quickActions: defaultActions)
    }

    private func enrichTransaction(_ object: CapturedObject, defaultActions: [QuickActionLink]) async -> EnrichmentResult {
        if object.chain == .solana {
            let exists = await solanaClient.transactionExists(signature: object.normalizedValue)
            let metadata = MetadataEnvelope(transaction: TransactionMetadata(
                transferSummary: nil,
                swapDetails: nil,
                confirmationState: exists ? "confirmed" : "unknown"
            ))
            return EnrichmentResult(state: exists ? .partial : .failed, metadata: metadata, quickActions: defaultActions)
        }

        if object.chain.isEVM {
            let exists = await evmClient.transactionExists(hash: object.normalizedValue, chain: object.chain)
            let metadata = MetadataEnvelope(transaction: TransactionMetadata(
                transferSummary: nil,
                swapDetails: nil,
                confirmationState: exists ? "confirmed" : "unknown"
            ))
            return EnrichmentResult(state: exists ? .partial : .failed, metadata: metadata, quickActions: defaultActions)
        }

        return EnrichmentResult(state: .partial, metadata: MetadataEnvelope(transaction: TransactionMetadata()), quickActions: defaultActions)
    }
}

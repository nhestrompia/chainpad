import CryptoScratchpadKit
import Foundation
import Testing

@MainActor
struct QuickActionBuilderTests {
    private func makeBuilder() -> DefaultQuickActionBuilder {
        let suiteName = "quick-actions-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let settings = SettingsStore(defaults: defaults)
        return DefaultQuickActionBuilder(settings: settings)
    }

    @Test
    func buildsSolanaSwapURL() {
        let builder = makeBuilder()
        let value = "So11111111111111111111111111111111111111112"
        let actions = builder.actions(type: .token, chain: .solana, value: value)

        let swap = actions.first { $0.label == "Swap" }
        #expect(swap?.url == "https://jup.ag/swap/SOL-\(value)")
    }

    @Test
    func buildsEVMExplorerURL() {
        let builder = makeBuilder()
        let value = "0x1234567890abcdef1234567890abcdef12345678"
        let actions = builder.actions(type: .wallet, chain: .base, value: value)

        let explorer = actions.first { $0.label == "Explorer" }
        #expect(explorer?.url == "https://basescan.org/address/\(value)")
    }

    @Test
    func buildsChainSpecificSwapURLs() {
        let builder = makeBuilder()
        let evmValue = "0x1234567890abcdef1234567890abcdef12345678"
        let solValue = "So11111111111111111111111111111111111111112"

        let solSwap = builder.actions(type: .token, chain: .solana, value: solValue).first { $0.label == "Swap" }
        let baseSwap = builder.actions(type: .token, chain: .base, value: evmValue).first { $0.label == "Swap" }
        let ethSwap = builder.actions(type: .token, chain: .ethereum, value: evmValue).first { $0.label == "Swap" }
        let bscSwap = builder.actions(type: .token, chain: .bsc, value: evmValue).first { $0.label == "Swap" }
        let arbSwap = builder.actions(type: .token, chain: .arbitrum, value: evmValue).first { $0.label == "Swap" }
        let polygonSwap = builder.actions(type: .token, chain: .polygon, value: evmValue).first { $0.label == "Swap" }

        #expect(solSwap?.url == "https://jup.ag/swap/SOL-\(solValue)")
        #expect(baseSwap?.url == "https://aerodrome.finance/swap")
        #expect(ethSwap?.url == "https://app.uniswap.org/#/swap?outputCurrency=\(evmValue)")
        #expect(bscSwap?.url == "https://pancakeswap.finance/swap?outputCurrency=\(evmValue)")
        #expect(arbSwap?.url == "https://app.uniswap.org/#/swap?outputCurrency=\(evmValue)")
        #expect(polygonSwap?.url == "https://app.uniswap.org/#/swap?outputCurrency=\(evmValue)")
    }
}

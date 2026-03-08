import Foundation

public struct QuickActionTemplate: Sendable, Hashable {
    public let id: String
    public let label: String
    public let supportedTypes: [CryptoObjectType]
    public let supportedChains: [Chain]?

    public init(id: String, label: String, supportedTypes: [CryptoObjectType], supportedChains: [Chain]? = nil) {
        self.id = id
        self.label = label
        self.supportedTypes = supportedTypes
        self.supportedChains = supportedChains
    }

    public func supports(chain: Chain, type: CryptoObjectType) -> Bool {
        guard supportedTypes.contains(type) else { return false }
        guard let supportedChains else { return true }
        return supportedChains.contains(chain)
    }
}

public enum QuickActionCatalog {
    public static let templates: [QuickActionTemplate] = [
        QuickActionTemplate(id: "chart", label: "Chart", supportedTypes: [.token, .pair]),
        QuickActionTemplate(id: "swap", label: "Swap", supportedTypes: [.token], supportedChains: [.solana, .ethereum, .base, .bsc, .arbitrum, .polygon, .unknown]),
        QuickActionTemplate(id: "explorer", label: "Explorer", supportedTypes: [.token, .wallet, .transaction]),
        QuickActionTemplate(id: "bubblemaps", label: "Bubblemaps", supportedTypes: [.token], supportedChains: [.solana, .ethereum, .base, .bsc, .arbitrum, .polygon]),
        QuickActionTemplate(id: "copy", label: "Copy", supportedTypes: [.token, .wallet, .transaction, .pair, .explorerLink]),

        // Optional additions by chain/type.
        QuickActionTemplate(id: "dexscreener", label: "DexScreener", supportedTypes: [.token, .pair]),
        QuickActionTemplate(id: "dextools", label: "DexTools", supportedTypes: [.token], supportedChains: [.ethereum, .base, .bsc, .arbitrum, .polygon]),
        QuickActionTemplate(id: "birdeye", label: "Birdeye", supportedTypes: [.token], supportedChains: [.solana]),
        QuickActionTemplate(id: "gmgn", label: "GMGN", supportedTypes: [.token], supportedChains: [.solana]),
        QuickActionTemplate(id: "photon", label: "Photon", supportedTypes: [.token], supportedChains: [.solana]),

        QuickActionTemplate(id: "solscan", label: "Solscan", supportedTypes: [.token, .wallet, .transaction], supportedChains: [.solana]),
        QuickActionTemplate(id: "etherscan", label: "Etherscan", supportedTypes: [.token, .wallet, .transaction], supportedChains: [.ethereum]),
        QuickActionTemplate(id: "basescan", label: "Basescan", supportedTypes: [.token, .wallet, .transaction], supportedChains: [.base]),
        QuickActionTemplate(id: "arbiscan", label: "Arbiscan", supportedTypes: [.token, .wallet, .transaction], supportedChains: [.arbitrum]),
        QuickActionTemplate(id: "bscscan", label: "BscScan", supportedTypes: [.token, .wallet, .transaction], supportedChains: [.bsc]),
        QuickActionTemplate(id: "polygonscan", label: "PolygonScan", supportedTypes: [.token, .wallet, .transaction], supportedChains: [.polygon]),

        QuickActionTemplate(id: "open", label: "Open", supportedTypes: [.explorerLink]),
    ]

    public static func availableTemplates(for chain: Chain, type: CryptoObjectType) -> [QuickActionTemplate] {
        templates.filter { $0.supports(chain: chain, type: type) }
    }

    public static func defaultTemplateIDs(for chain: Chain, type: CryptoObjectType) -> [String] {
        switch type {
        case .token:
            return ["chart", "swap", "explorer", "bubblemaps", "copy"]
        case .wallet:
            return ["explorer", "copy"]
        case .transaction:
            return ["explorer", "copy"]
        case .pair:
            return ["chart", "copy"]
        case .explorerLink:
            return ["open", "copy"]
        }
    }

    public static func link(for templateID: String, chain: Chain, type: CryptoObjectType, value: String) -> QuickActionLink? {
        switch templateID {
        case "chart":
            if chain == .solana {
                return QuickActionLink(label: "Chart", url: "https://birdeye.so/token/\(value)?chain=solana")
            }
            return QuickActionLink(label: "Chart", url: "https://dexscreener.com/search?q=\(value)")

        case "swap":
            if chain == .solana {
                return QuickActionLink(label: "Swap", url: "https://jup.ag/swap/SOL-\(value)")
            }
            if chain == .base {
                return QuickActionLink(label: "Swap", url: "https://aerodrome.finance/swap")
            }
            if chain == .bsc {
                return QuickActionLink(label: "Swap", url: "https://pancakeswap.finance/swap?outputCurrency=\(value)")
            }
            if chain == .ethereum || chain == .arbitrum || chain == .polygon {
                return QuickActionLink(label: "Swap", url: "https://app.uniswap.org/#/swap?outputCurrency=\(value)")
            }
            return QuickActionLink(label: "Swap", url: "https://dexscreener.com/search?q=\(value)")

        case "explorer":
            return QuickActionLink(label: "Explorer", url: explorerURL(for: chain, type: type, value: value))

        case "bubblemaps":
            return QuickActionLink(label: "Bubblemaps", url: "https://app.bubblemaps.io/\(chain.rawValue)/token/\(value)")

        case "copy":
            return QuickActionLink(label: "Copy", url: "copy://\(value)")

        case "dexscreener":
            return QuickActionLink(label: "DexScreener", url: "https://dexscreener.com/search?q=\(value)")

        case "dextools":
            return QuickActionLink(label: "DexTools", url: "https://www.dextools.io/app/en/\(chain.rawValue)/pair-explorer/\(value)")

        

        case "birdeye":
            return QuickActionLink(label: "Birdeye", url: "https://birdeye.so/token/\(value)?chain=solana")

        case "gmgn":
            return QuickActionLink(label: "GMGN", url: "https://gmgn.ai/sol/token/\(value)")

        case "photon":
            return QuickActionLink(label: "Photon", url: "https://photon-sol.tinyastro.io/en/lp/\(value)")

        case "solscan":
            switch type {
            case .transaction:
                return QuickActionLink(label: "Solscan", url: "https://solscan.io/tx/\(value)")
            case .wallet:
                return QuickActionLink(label: "Solscan", url: "https://solscan.io/account/\(value)")
            case .token:
                return QuickActionLink(label: "Solscan", url: "https://solscan.io/token/\(value)")
            case .pair, .explorerLink:
                return nil
            }

        case "etherscan":
            return QuickActionLink(label: "Etherscan", url: evmExplorer(base: "https://etherscan.io", type: type, value: value))

        case "basescan":
            return QuickActionLink(label: "Basescan", url: evmExplorer(base: "https://basescan.org", type: type, value: value))

        case "arbiscan":
            return QuickActionLink(label: "Arbiscan", url: evmExplorer(base: "https://arbiscan.io", type: type, value: value))

        case "bscscan":
            return QuickActionLink(label: "BscScan", url: evmExplorer(base: "https://bscscan.com", type: type, value: value))

        case "polygonscan":
            return QuickActionLink(label: "PolygonScan", url: evmExplorer(base: "https://polygonscan.com", type: type, value: value))

        case "open":
            return QuickActionLink(label: "Open", url: value)

        default:
            return nil
        }
    }

    private static func explorerURL(for chain: Chain, type: CryptoObjectType, value: String) -> String {
        switch chain {
        case .solana:
            switch type {
            case .transaction:
                return "https://solscan.io/tx/\(value)"
            case .wallet:
                return "https://solscan.io/account/\(value)"
            case .token:
                return "https://solscan.io/token/\(value)"
            case .pair, .explorerLink:
                return "https://solscan.io"
            }
        case .ethereum:
            return evmExplorer(base: "https://etherscan.io", type: type, value: value)
        case .base:
            return evmExplorer(base: "https://basescan.org", type: type, value: value)
        case .bsc:
            return evmExplorer(base: "https://bscscan.com", type: type, value: value)
        case .arbitrum:
            return evmExplorer(base: "https://arbiscan.io", type: type, value: value)
        case .polygon:
            return evmExplorer(base: "https://polygonscan.com", type: type, value: value)
        case .unknown:
            return "https://dexscreener.com/search?q=\(value)"
        }
    }

    private static func evmExplorer(base: String, type: CryptoObjectType, value: String) -> String {
        switch type {
        case .transaction:
            return "\(base)/tx/\(value)"
        case .token:
            return "\(base)/token/\(value)"
        case .wallet:
            return "\(base)/address/\(value)"
        case .pair, .explorerLink:
            return base
        }
    }
}

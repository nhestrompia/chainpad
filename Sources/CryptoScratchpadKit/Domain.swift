import Foundation

public let internalCopyPasteboardMarker = "com.cryptoscratchpad.internal-copy"

public enum CryptoObjectType: String, Codable, CaseIterable, Sendable {
    case token
    case wallet
    case transaction
    case pair
    case explorerLink
}

public enum Chain: String, Codable, CaseIterable, Sendable {
    case solana
    case ethereum
    case base
    case bsc
    case arbitrum
    case polygon
    case unknown
}

public enum ValidationState: String, Codable, Sendable {
    case pending
    case valid
    case invalid
}

public enum EnrichmentState: String, Codable, Sendable {
    case none
    case queued
    case partial
    case complete
    case failed
}

public enum DetectionKind: Sendable {
    case evmAddress
    case solanaAddress
    case evmTransaction
    case solanaTransaction
    case explorerURL
    case pairURL
}

public struct ClipboardEvent: Sendable {
    public let text: String
    public let sourceAppBundleID: String?
    public let sourceAppName: String?
    public let sourcePageURL: String?
    public let frontmostAppBundleID: String?
    public let frontmostAppName: String?
    public let capturedAt: Date

    public init(
        text: String,
        sourceAppBundleID: String?,
        sourceAppName: String?,
        sourcePageURL: String?,
        frontmostAppBundleID: String? = nil,
        frontmostAppName: String? = nil,
        capturedAt: Date
    ) {
        self.text = text
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.sourcePageURL = sourcePageURL
        self.frontmostAppBundleID = frontmostAppBundleID
        self.frontmostAppName = frontmostAppName
        self.capturedAt = capturedAt
    }
}

public struct DetectionResult: Sendable {
    public let rawValue: String
    public let normalizedValue: String
    public let kind: DetectionKind
    public let type: CryptoObjectType
    public let chainHint: Chain

    public init(rawValue: String, normalizedValue: String, kind: DetectionKind, type: CryptoObjectType, chainHint: Chain) {
        self.rawValue = rawValue
        self.normalizedValue = normalizedValue
        self.kind = kind
        self.type = type
        self.chainHint = chainHint
    }
}

public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let type: CryptoObjectType
    public let chain: Chain

    public init(isValid: Bool, type: CryptoObjectType, chain: Chain) {
        self.isValid = isValid
        self.type = type
        self.chain = chain
    }
}

public struct TokenMetadata: Codable, Sendable {
    public var name: String?
    public var symbol: String?
    public var priceUSD: Double?
    public var liquidityUSD: Double?
    public var marketCapUSD: Double?
    public var ageDays: Int?
    public var imageURL: String?
    public var websiteURL: String?
    public var twitterURL: String?
    public var telegramURL: String?

    public init(
        name: String? = nil,
        symbol: String? = nil,
        priceUSD: Double? = nil,
        liquidityUSD: Double? = nil,
        marketCapUSD: Double? = nil,
        ageDays: Int? = nil,
        imageURL: String? = nil,
        websiteURL: String? = nil,
        twitterURL: String? = nil,
        telegramURL: String? = nil
    ) {
        self.name = name
        self.symbol = symbol
        self.priceUSD = priceUSD
        self.liquidityUSD = liquidityUSD
        self.marketCapUSD = marketCapUSD
        self.ageDays = ageDays
        self.imageURL = imageURL
        self.websiteURL = websiteURL
        self.twitterURL = twitterURL
        self.telegramURL = telegramURL
    }
}

public struct WalletMetadata: Codable, Sendable {
    public var balance: Double?
    public var transactionCount: Int?
    public var label: String?

    public init(balance: Double? = nil, transactionCount: Int? = nil, label: String? = nil) {
        self.balance = balance
        self.transactionCount = transactionCount
        self.label = label
    }
}

public struct TransactionMetadata: Codable, Sendable {
    public var transferSummary: String?
    public var swapDetails: String?
    public var confirmationState: String?

    public init(transferSummary: String? = nil, swapDetails: String? = nil, confirmationState: String? = nil) {
        self.transferSummary = transferSummary
        self.swapDetails = swapDetails
        self.confirmationState = confirmationState
    }
}

public struct MetadataEnvelope: Codable, Sendable {
    public var token: TokenMetadata?
    public var wallet: WalletMetadata?
    public var transaction: TransactionMetadata?

    public init(token: TokenMetadata? = nil, wallet: WalletMetadata? = nil, transaction: TransactionMetadata? = nil) {
        self.token = token
        self.wallet = wallet
        self.transaction = transaction
    }
}

public struct QuickActionLink: Codable, Hashable, Sendable {
    public var label: String
    public var url: String

    public init(label: String, url: String) {
        self.label = label
        self.url = url
    }
}

public struct EnrichmentResult: Sendable {
    public let state: EnrichmentState
    public let metadata: MetadataEnvelope?
    public let quickActions: [QuickActionLink]

    public init(state: EnrichmentState, metadata: MetadataEnvelope?, quickActions: [QuickActionLink]) {
        self.state = state
        self.metadata = metadata
        self.quickActions = quickActions
    }
}

@MainActor
public protocol ClipboardMonitor: AnyObject {
    var events: AsyncStream<ClipboardEvent> { get }
    func start()
    func stop()
}

@MainActor
public protocol Detector: AnyObject {
    func detect(_ text: String) -> DetectionResult?
}

@MainActor
public protocol Validator: AnyObject {
    func validate(_ detection: DetectionResult) async -> ValidationResult
}

@MainActor
public protocol Enricher: AnyObject {
    func enrich(_ object: CapturedObject) async -> EnrichmentResult
}

@MainActor
public protocol ScratchpadRepository: AnyObject {
    func upsert(
        event: ClipboardEvent,
        detection: DetectionResult,
        validation: ValidationResult,
        defaultActions: [QuickActionLink]
    ) throws -> CapturedObject
    func fetchSession() throws -> [CapturedObject]
    func fetchPinned() throws -> [CapturedObject]
    func search(_ query: String) throws -> [CapturedObject]
    func pin(_ object: CapturedObject) throws
    func unpin(_ object: CapturedObject) throws
    func clearExpired(before cutoff: Date) throws
    func clearSession() throws
    func delete(id: UUID) throws
    func saveEnrichment(for objectID: UUID, result: EnrichmentResult) throws
    func saveQuickActions(for objectID: UUID, actions: [QuickActionLink]) throws
    func find(id: UUID) throws -> CapturedObject?
    func rename(id: UUID, customName: String?) throws
}

@MainActor
public protocol QuickActionBuilder: AnyObject {
    func actions(type: CryptoObjectType, chain: Chain, value: String) -> [QuickActionLink]
    func actions(for object: CapturedObject) -> [QuickActionLink]
}

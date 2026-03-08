import Foundation
import SwiftData

@Model
public final class CapturedObject {
    @Attribute(.unique) public var dedupeKey: String
    public var id: UUID
    public var rawValue: String
    public var normalizedValue: String
    public var typeRaw: String
    public var chainRaw: String
    public var sourceAppBundleID: String?
    public var sourceAppName: String?
    public var sourcePageURL: String?
    public var customName: String?
    public var firstSeenAt: Date
    public var lastSeenAt: Date
    public var pinnedAt: Date?
    public var isPinned: Bool
    public var validationStateRaw: String
    public var enrichmentStateRaw: String
    public var metadataBlob: Data?
    public var quickActionLinksBlob: Data?
    public var hitCount: Int
    public var searchIndex: String

    public init(
        dedupeKey: String,
        id: UUID,
        rawValue: String,
        normalizedValue: String,
        type: CryptoObjectType,
        chain: Chain,
        sourceAppBundleID: String?,
        sourceAppName: String?,
        sourcePageURL: String? = nil,
        customName: String? = nil,
        firstSeenAt: Date,
        lastSeenAt: Date,
        pinnedAt: Date? = nil,
        isPinned: Bool,
        validationState: ValidationState,
        enrichmentState: EnrichmentState,
        metadataBlob: Data? = nil,
        quickActionLinksBlob: Data? = nil,
        hitCount: Int,
        searchIndex: String
    ) {
        self.dedupeKey = dedupeKey
        self.id = id
        self.rawValue = rawValue
        self.normalizedValue = normalizedValue
        self.typeRaw = type.rawValue
        self.chainRaw = chain.rawValue
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.sourcePageURL = sourcePageURL
        self.customName = customName
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.pinnedAt = pinnedAt
        self.isPinned = isPinned
        self.validationStateRaw = validationState.rawValue
        self.enrichmentStateRaw = enrichmentState.rawValue
        self.metadataBlob = metadataBlob
        self.quickActionLinksBlob = quickActionLinksBlob
        self.hitCount = hitCount
        self.searchIndex = searchIndex
    }
}

public extension CapturedObject {
    var type: CryptoObjectType {
        get { CryptoObjectType(rawValue: typeRaw) ?? .explorerLink }
        set { typeRaw = newValue.rawValue }
    }

    var chain: Chain {
        get { Chain(rawValue: chainRaw) ?? .unknown }
        set { chainRaw = newValue.rawValue }
    }

    var validationState: ValidationState {
        get { ValidationState(rawValue: validationStateRaw) ?? .pending }
        set { validationStateRaw = newValue.rawValue }
    }

    var enrichmentState: EnrichmentState {
        get { EnrichmentState(rawValue: enrichmentStateRaw) ?? .none }
        set { enrichmentStateRaw = newValue.rawValue }
    }

    var metadata: MetadataEnvelope? {
        get {
            guard let metadataBlob else { return nil }
            return try? JSONDecoder().decode(MetadataEnvelope.self, from: metadataBlob)
        }
        set {
            metadataBlob = try? JSONEncoder().encode(newValue)
        }
    }

    var quickActions: [QuickActionLink] {
        get {
            guard let quickActionLinksBlob else { return [] }
            return (try? JSONDecoder().decode([QuickActionLink].self, from: quickActionLinksBlob)) ?? []
        }
        set {
            quickActionLinksBlob = try? JSONEncoder().encode(newValue)
        }
    }

    func updateSearchIndex() {
        var parts = [normalizedValue, rawValue, type.rawValue, chain.rawValue]
        if let sourceAppName {
            parts.append(sourceAppName)
        }
        if let sourcePageURL {
            parts.append(sourcePageURL)
        }
        if let customName, !customName.isEmpty {
            parts.append(customName)
        }
        if let tokenName = metadata?.token?.name {
            parts.append(tokenName)
        }
        if let symbol = metadata?.token?.symbol {
            parts.append(symbol)
        }
        searchIndex = parts
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func dedupeKey(normalizedValue: String, type: CryptoObjectType, chain: Chain) -> String {
        "\(normalizedValue.lowercased())::\(type.rawValue)::\(chain.rawValue)"
    }
}

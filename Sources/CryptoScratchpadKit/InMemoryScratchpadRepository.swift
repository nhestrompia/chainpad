import Foundation

@MainActor
public final class InMemoryScratchpadRepository: ScratchpadRepository {
    private var items: [CapturedObject] = []

    public init() {}

    public func upsert(
        event: ClipboardEvent,
        detection: DetectionResult,
        validation: ValidationResult,
        defaultActions: [QuickActionLink]
    ) throws -> CapturedObject {
        let dedupeKey = CapturedObject.dedupeKey(
            normalizedValue: detection.normalizedValue,
            type: validation.type,
            chain: validation.chain
        )

        if let existing = items.first(where: { $0.dedupeKey == dedupeKey }) {
            existing.rawValue = detection.rawValue
            existing.hitCount += 1
            existing.validationState = .valid
            existing.enrichmentState = .queued
            existing.sourceAppBundleID = event.sourceAppBundleID
            existing.sourceAppName = event.sourceAppName
            existing.sourcePageURL = event.sourcePageURL
            existing.type = validation.type
            existing.chain = validation.chain
            existing.quickActions = defaultActions
            existing.updateSearchIndex()
            return existing
        }

        if let existingValue = items.first(where: {
            $0.normalizedValue == detection.normalizedValue && $0.chain == validation.chain
        }) {
            existingValue.dedupeKey = dedupeKey
            existingValue.rawValue = detection.rawValue
            existingValue.hitCount += 1
            existingValue.validationState = .valid
            existingValue.enrichmentState = .queued
            existingValue.sourceAppBundleID = event.sourceAppBundleID
            existingValue.sourceAppName = event.sourceAppName
            existingValue.sourcePageURL = event.sourcePageURL
            existingValue.type = validation.type
            existingValue.chain = validation.chain
            existingValue.quickActions = defaultActions
            existingValue.updateSearchIndex()
            return existingValue
        }

        let object = CapturedObject(
            dedupeKey: dedupeKey,
            id: UUID(),
            rawValue: detection.rawValue,
            normalizedValue: detection.normalizedValue,
            type: validation.type,
            chain: validation.chain,
            sourceAppBundleID: event.sourceAppBundleID,
            sourceAppName: event.sourceAppName,
            sourcePageURL: event.sourcePageURL,
            customName: nil,
            firstSeenAt: event.capturedAt,
            lastSeenAt: event.capturedAt,
            isPinned: false,
            validationState: .valid,
            enrichmentState: .queued,
            metadataBlob: nil,
            quickActionLinksBlob: try? JSONEncoder().encode(defaultActions),
            hitCount: 1,
            searchIndex: ""
        )

        object.updateSearchIndex()
        items.append(object)
        return object
    }

    public func fetchSession() throws -> [CapturedObject] {
        items
            .filter { !$0.isPinned }
            .sorted { $0.lastSeenAt > $1.lastSeenAt }
    }

    public func fetchPinned() throws -> [CapturedObject] {
        items
            .filter { $0.isPinned }
            .sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
    }

    public func search(_ query: String) throws -> [CapturedObject] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let source: [CapturedObject]
        if normalized.isEmpty {
            source = items
        } else {
            source = items.filter { $0.searchIndex.contains(normalized) }
        }

        return source.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.lastSeenAt > rhs.lastSeenAt
        }
    }

    public func pin(_ object: CapturedObject) throws {
        object.isPinned = true
        object.pinnedAt = Date()
    }

    public func unpin(_ object: CapturedObject) throws {
        object.isPinned = false
        object.pinnedAt = nil
        object.lastSeenAt = Date()
    }

    public func clearExpired(before cutoff: Date) throws {
        items.removeAll { !$0.isPinned && $0.lastSeenAt < cutoff }
    }

    public func clearSession() throws {
        items.removeAll { !$0.isPinned }
    }

    public func delete(id: UUID) throws {
        items.removeAll { $0.id == id }
    }

    public func saveEnrichment(for objectID: UUID, result: EnrichmentResult) throws {
        guard let object = try find(id: objectID) else { return }

        object.enrichmentState = result.state
        object.metadata = result.metadata
        object.quickActions = result.quickActions
        object.updateSearchIndex()
    }

    public func saveQuickActions(for objectID: UUID, actions: [QuickActionLink]) throws {
        guard let object = try find(id: objectID) else { return }
        object.quickActions = actions
        object.updateSearchIndex()
    }

    public func find(id: UUID) throws -> CapturedObject? {
        items.first { $0.id == id }
    }

    public func rename(id: UUID, customName: String?) throws {
        guard let object = try find(id: id) else { return }
        let normalized = customName?.trimmingCharacters(in: .whitespacesAndNewlines)
        object.customName = (normalized?.isEmpty == true) ? nil : normalized
        object.updateSearchIndex()
    }
}

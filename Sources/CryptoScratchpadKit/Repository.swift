import Foundation
import SwiftData

@MainActor
public final class SwiftDataScratchpadRepository: ScratchpadRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

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

        let descriptor = FetchDescriptor<CapturedObject>(
            predicate: #Predicate { $0.dedupeKey == dedupeKey }
        )

        if let existing = try context.fetch(descriptor).first {
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
            try context.save()
            return existing
        }

        // Upgrade an existing row when better classification resolves the same value.
        let normalizedValue = detection.normalizedValue
        let chainRaw = validation.chain.rawValue
        let valueDescriptor = FetchDescriptor<CapturedObject>(
            predicate: #Predicate {
                $0.normalizedValue == normalizedValue && $0.chainRaw == chainRaw
            }
        )
        if let existingValue = try context.fetch(valueDescriptor).first {
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
            try context.save()
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
        context.insert(object)
        try context.save()
        return object
    }

    public func fetchSession() throws -> [CapturedObject] {
        var descriptor = FetchDescriptor<CapturedObject>(
            predicate: #Predicate { !$0.isPinned },
            sortBy: [SortDescriptor(\CapturedObject.lastSeenAt, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        return try context.fetch(descriptor)
    }

    public func fetchPinned() throws -> [CapturedObject] {
        var descriptor = FetchDescriptor<CapturedObject>(
            predicate: #Predicate { $0.isPinned },
            sortBy: [SortDescriptor(\CapturedObject.pinnedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        return try context.fetch(descriptor)
    }

    public func search(_ query: String) throws -> [CapturedObject] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var descriptor = FetchDescriptor<CapturedObject>()
        descriptor.fetchLimit = 1_000
        let allObjects = try context.fetch(descriptor)

        guard !normalized.isEmpty else {
            return allObjects.sorted(by: { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.lastSeenAt > rhs.lastSeenAt
            })
        }

        return allObjects
            .filter { $0.searchIndex.contains(normalized) }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.lastSeenAt > rhs.lastSeenAt
            }
    }

    public func pin(_ object: CapturedObject) throws {
        object.isPinned = true
        object.pinnedAt = Date()
        try context.save()
    }

    public func unpin(_ object: CapturedObject) throws {
        object.isPinned = false
        object.pinnedAt = nil
        object.lastSeenAt = Date()
        try context.save()
    }

    public func clearExpired(before cutoff: Date) throws {
        let descriptor = FetchDescriptor<CapturedObject>(
            predicate: #Predicate { !$0.isPinned && $0.lastSeenAt < cutoff }
        )

        for object in try context.fetch(descriptor) {
            context.delete(object)
        }

        try context.save()
    }

    public func clearSession() throws {
        let descriptor = FetchDescriptor<CapturedObject>(
            predicate: #Predicate { !$0.isPinned }
        )

        for object in try context.fetch(descriptor) {
            context.delete(object)
        }

        try context.save()
    }

    public func delete(id: UUID) throws {
        guard let object = try find(id: id) else { return }
        context.delete(object)
        try context.save()
    }

    public func saveEnrichment(for objectID: UUID, result: EnrichmentResult) throws {
        guard let object = try find(id: objectID) else { return }

        object.enrichmentState = result.state
        object.metadata = result.metadata
        object.quickActions = result.quickActions
        object.updateSearchIndex()

        try context.save()
    }

    public func saveQuickActions(for objectID: UUID, actions: [QuickActionLink]) throws {
        guard let object = try find(id: objectID) else { return }
        object.quickActions = actions
        object.updateSearchIndex()
        try context.save()
    }

    public func find(id: UUID) throws -> CapturedObject? {
        let descriptor = FetchDescriptor<CapturedObject>(
            predicate: #Predicate { $0.id == id }
        )

        return try context.fetch(descriptor).first
    }

    public func rename(id: UUID, customName: String?) throws {
        guard let object = try find(id: id) else { return }
        let normalized = customName?.trimmingCharacters(in: .whitespacesAndNewlines)
        object.customName = (normalized?.isEmpty == true) ? nil : normalized
        object.updateSearchIndex()
        try context.save()
    }
}

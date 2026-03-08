import Foundation
import Observation

@MainActor
@Observable
public final class ScratchpadStore {
    public private(set) var sessionItems: [CapturedObject] = []
    public private(set) var pinnedItems: [CapturedObject] = []
    public private(set) var searchResults: [CapturedObject] = []
    public private(set) var lastErrorMessage: String?

    public var searchQuery: String = "" {
        didSet {
            scheduleSearch()
        }
    }

    public var shouldShowSearchResults: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var menuBarItemCount: Int {
        sessionItems.count
    }

    public var menuBarLabel: String {
        menuBarItemCount == 0 ? "📌" : "📌 \(menuBarItemCount)"
    }

    public var settings: SettingsStore

    private let monitor: ClipboardMonitor
    private let detector: Detector
    private let validator: Validator
    private let enricher: Enricher
    private let repository: ScratchpadRepository
    private let quickActionBuilder: QuickActionBuilder

    private var monitorTask: Task<Void, Never>?
    private var cleanupTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var started = false

    public init(
        monitor: ClipboardMonitor,
        detector: Detector,
        validator: Validator,
        enricher: Enricher,
        repository: ScratchpadRepository,
        quickActionBuilder: QuickActionBuilder,
        settings: SettingsStore
    ) {
        self.monitor = monitor
        self.detector = detector
        self.validator = validator
        self.enricher = enricher
        self.repository = repository
        self.quickActionBuilder = quickActionBuilder
        self.settings = settings
    }

    public func start() {
        guard !started else { return }
        started = true

        monitor.start()

        monitorTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshAll()
            self.applyQuickActionPreferencesToExistingItems()
            await self.clearExpired()
            await self.backfillMissingTokenMetadata()

            for await event in monitor.events {
                if Task.isCancelled {
                    break
                }
                await self.process(event: event)
            }
        }

        cleanupTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30 * 60))
                await self.clearExpired()
            }
        }
    }

    public func stop() {
        monitor.stop()
        monitorTask?.cancel()
        cleanupTask?.cancel()
        searchTask?.cancel()
        monitorTask = nil
        cleanupTask = nil
        searchTask = nil
        started = false
    }

    public func setPinned(_ object: CapturedObject, pinned: Bool) {
        do {
            if pinned {
                try repository.pin(object)
            } else {
                try repository.unpin(object)
            }
            refreshSync()
        } catch {
            lastErrorMessage = "Failed to update pin state: \(error.localizedDescription)"
        }
    }

    public func clearSession() {
        do {
            try repository.clearSession()
            refreshSync()
        } catch {
            lastErrorMessage = "Failed to clear session: \(error.localizedDescription)"
        }
    }

    public func retryEnrichment(for object: CapturedObject) {
        enqueueEnrichment(objectID: object.id)
    }

    public func rename(_ object: CapturedObject, customName: String?) {
        do {
            try repository.rename(id: object.id, customName: customName)
            refreshSync()
        } catch {
            lastErrorMessage = "Failed to rename item: \(error.localizedDescription)"
        }
    }

    public func delete(_ object: CapturedObject) {
        do {
            try repository.delete(id: object.id)
            refreshSync()
        } catch {
            lastErrorMessage = "Failed to delete item: \(error.localizedDescription)"
        }
    }

    public func applyQuickActionPreferencesToExistingItems() {
        do {
            let all = try repository.search("")
            for object in all {
                let actions = quickActionBuilder.actions(for: object)
                try repository.saveQuickActions(for: object.id, actions: actions)
            }
            refreshSync()
        } catch {
            lastErrorMessage = "Failed to apply quick action changes: \(error.localizedDescription)"
        }
    }

    public func refreshSync() {
        do {
            pinnedItems = try repository.fetchPinned()
            sessionItems = try repository.fetchSession()
            if shouldShowSearchResults {
                searchResults = try repository.search(searchQuery)
            }
        } catch {
            lastErrorMessage = "Failed to load scratchpad: \(error.localizedDescription)"
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        let query = searchQuery
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self, !Task.isCancelled else { return }
            self.performSearch(query)
        }
    }

    private func performSearch(_ query: String) {
        do {
            searchResults = try repository.search(query)
        } catch {
            lastErrorMessage = "Search failed: \(error.localizedDescription)"
        }
    }

    private func refreshAll() async {
        refreshSync()
    }

    private func clearExpired() async {
        guard settings.sessionTTLHours > 0 else { return }
        let ttlSeconds = settings.sessionTTLHours * 3600
        let cutoff = Date().addingTimeInterval(-ttlSeconds)

        do {
            try repository.clearExpired(before: cutoff)
            refreshSync()
        } catch {
            lastErrorMessage = "Failed to clear expired session items: \(error.localizedDescription)"
        }
    }

    private func backfillMissingTokenMetadata() async {
        let candidates = (pinnedItems + sessionItems)
            .filter { object in
                guard object.type == .token else { return false }
                guard let token = object.metadata?.token else { return true }
                let hasImage = !(token.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                let hasSocial = !(token.websiteURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                    || !(token.twitterURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                    || !(token.telegramURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                return !(hasImage || hasSocial)
            }
            .prefix(30)

        for object in candidates {
            enqueueEnrichment(objectID: object.id)
        }
    }

    private func process(event: ClipboardEvent) async {
        guard !isInternalClipboardEvent(event) else { return }
        guard !settings.capturePaused else { return }
        guard !settings.isBlacklisted(bundleID: event.sourceAppBundleID) else { return }

        guard let detection = detector.detect(event.text) else { return }
        let validation = await validator.validate(detection)
        guard validation.isValid else { return }

        do {
            let defaultActions = quickActionBuilder.actions(
                type: validation.type,
                chain: validation.chain,
                value: detection.normalizedValue
            )

            let object = try repository.upsert(
                event: event,
                detection: detection,
                validation: validation,
                defaultActions: defaultActions
            )
            refreshSync()
            enqueueEnrichment(objectID: object.id)
        } catch {
            lastErrorMessage = "Failed to persist capture: \(error.localizedDescription)"
        }
    }

    private func enqueueEnrichment(objectID: UUID) {
        Task { [weak self] in
            guard let self else { return }

            for attempt in 0...2 {
                do {
                    guard let object = try repository.find(id: objectID) else { return }
                    let result = await enricher.enrich(object)

                    if result.state == .failed, attempt < 2 {
                        try? await Task.sleep(for: .seconds(pow(2, Double(attempt))))
                        continue
                    }

                    try repository.saveEnrichment(for: objectID, result: result)
                    refreshSync()
                    return
                } catch {
                    if attempt == 2 {
                        lastErrorMessage = "Failed enrichment: \(error.localizedDescription)"
                    } else {
                        try? await Task.sleep(for: .seconds(pow(2, Double(attempt))))
                    }
                }
            }
        }
    }

    private func isInternalClipboardEvent(_ event: ClipboardEvent) -> Bool {
        let appBundleID = Bundle.main.bundleIdentifier
        if let frontmostBundleID = event.frontmostAppBundleID,
           let appBundleID,
           frontmostBundleID == appBundleID {
            return true
        }

        let frontmostName = (event.frontmostAppName ?? "").lowercased()
        if frontmostName.contains("cryptoscratchpad") {
            return true
        }

        return false
    }
}

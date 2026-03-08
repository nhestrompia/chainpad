import Foundation
import Observation

@MainActor
@Observable
public final class SettingsStore {
    private enum Keys {
        static let capturePaused = "capturePaused"
        static let ttlHours = "sessionTTLHours"
        static let blacklistedBundleIDs = "blacklistedBundleIDs"
        static let quickActionPreferences = "quickActionPreferences"
        static let autoOpenOnLaunch = "autoOpenOnLaunch"
    }

    private let defaults: UserDefaults
    private var quickActionPreferences: [String: [String]]

    public var capturePaused: Bool {
        didSet { defaults.set(capturePaused, forKey: Keys.capturePaused) }
    }

    public var autoOpenOnLaunch: Bool {
        didSet { defaults.set(autoOpenOnLaunch, forKey: Keys.autoOpenOnLaunch) }
    }

    public var sessionTTLHours: Double {
        didSet {
            if sessionTTLHours < 0 {
                sessionTTLHours = 0
                return
            }
            defaults.set(sessionTTLHours, forKey: Keys.ttlHours)
        }
    }

    public var blacklistedBundleIDs: [String] {
        didSet {
            let normalized = Array(Set(blacklistedBundleIDs.filter { !$0.isEmpty })).sorted()
            if normalized != blacklistedBundleIDs {
                blacklistedBundleIDs = normalized
                return
            }
            defaults.set(normalized, forKey: Keys.blacklistedBundleIDs)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.capturePaused = defaults.bool(forKey: Keys.capturePaused)
        self.autoOpenOnLaunch = defaults.bool(forKey: Keys.autoOpenOnLaunch)

        let configuredTTL = defaults.object(forKey: Keys.ttlHours) as? Double
        self.sessionTTLHours = configuredTTL ?? 24

        self.blacklistedBundleIDs = defaults.stringArray(forKey: Keys.blacklistedBundleIDs) ?? []

        if let data = defaults.data(forKey: Keys.quickActionPreferences),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            self.quickActionPreferences = decoded
        } else {
            self.quickActionPreferences = [:]
        }
    }

    public func isBlacklisted(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return blacklistedBundleIDs.contains(bundleID)
    }

    public func addBlacklist(bundleID: String) {
        blacklistedBundleIDs.append(bundleID.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public func removeBlacklist(bundleID: String) {
        blacklistedBundleIDs.removeAll { $0 == bundleID }
    }

    public func enabledQuickActionIDs(
        for chain: Chain,
        type: CryptoObjectType,
        availableIDs: [String],
        defaultIDs: [String]
    ) -> [String] {
        let key = quickActionPreferenceKey(chain: chain, type: type)
        let stored = quickActionPreferences[key] ?? defaultIDs
        return stored.filter { availableIDs.contains($0) }
    }

    public func setEnabledQuickActionIDs(_ ids: [String], for chain: Chain, type: CryptoObjectType) {
        let key = quickActionPreferenceKey(chain: chain, type: type)
        quickActionPreferences[key] = ids
        persistQuickActionPreferences()
    }

    public func resetQuickActionIDs(for chain: Chain, type: CryptoObjectType) {
        let key = quickActionPreferenceKey(chain: chain, type: type)
        quickActionPreferences.removeValue(forKey: key)
        persistQuickActionPreferences()
    }

    private func quickActionPreferenceKey(chain: Chain, type: CryptoObjectType) -> String {
        "\(chain.rawValue)::\(type.rawValue)"
    }

    private func persistQuickActionPreferences() {
        guard let data = try? JSONEncoder().encode(quickActionPreferences) else { return }
        defaults.set(data, forKey: Keys.quickActionPreferences)
    }
}

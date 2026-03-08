import Foundation

@MainActor
public final class DefaultQuickActionBuilder: QuickActionBuilder {
    private let settings: SettingsStore

    public init(settings: SettingsStore) {
        self.settings = settings
    }

    public func actions(type: CryptoObjectType, chain: Chain, value: String) -> [QuickActionLink] {
        let templates = QuickActionCatalog.availableTemplates(for: chain, type: type)
        let availableIDs = templates.map(\.id)
        let defaultIDs = QuickActionCatalog.defaultTemplateIDs(for: chain, type: type)

        let enabledIDs = settings.enabledQuickActionIDs(
            for: chain,
            type: type,
            availableIDs: availableIDs,
            defaultIDs: defaultIDs
        )

        return enabledIDs.compactMap { templateID in
            QuickActionCatalog.link(for: templateID, chain: chain, type: type, value: value)
        }
    }

    public func actions(for object: CapturedObject) -> [QuickActionLink] {
        actions(type: object.type, chain: object.chain, value: object.normalizedValue)
    }
}

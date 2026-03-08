import AppKit
import CryptoScratchpadKit
import Observation
import SwiftUI

private enum SettingsTab: String, CaseIterable {
    case general = "General"
    case quickActions = "Quick Actions"
    case apps = "Apps"
}

private enum TTLSelection: String, CaseIterable {
    case h8 = "8h"
    case h24 = "24h"
    case h72 = "72h"
    case custom = "Custom"
    case never = "Never"
}

private struct AppOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let bundleID: String
    let appPath: String
}

private struct AppIconView: View {
    let appPath: String
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 20, height: 20)
        .onAppear {
            guard icon == nil else { return }
            let image = NSWorkspace.shared.icon(forFile: appPath)
            image.size = NSSize(width: 20, height: 20)
            icon = image
        }
    }
}

struct SettingsPanelView: View {
    @Bindable var store: ScratchpadStore

    @State private var selectedTab: SettingsTab = .general
    @State private var selectedTTL: TTLSelection = .h24
    @State private var customTTLInput = "24"

    @State private var installedApps: [AppOption] = []
    @State private var isLoadingInstalledApps = false
    @State private var appSearchQuery = ""

    @State private var showManualAppEntry = false
    @State private var newBundleID = ""

    @State private var quickActionChain: Chain = .solana
    @State private var quickActionType: CryptoObjectType = .token

    private let compactTTLColumns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    private var filteredApps: [AppOption] {
        let query = appSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return installedApps }

        return installedApps.filter { app in
            app.name.lowercased().contains(query) || app.bundleID.lowercased().contains(query)
        }
    }

    private var trackedCount: Int {
        installedApps.filter { isTracked(bundleID: $0.bundleID) }.count
    }

    private var ignoredCount: Int {
        installedApps.count - trackedCount
    }

    private var manuallyIgnoredBundleIDs: [String] {
        let installedBundleIDs = Set(installedApps.map { $0.bundleID })
        return store.settings.blacklistedBundleIDs
            .filter { !installedBundleIDs.contains($0) }
            .sorted()
    }

    private var quickActionTemplates: [QuickActionTemplate] {
        QuickActionCatalog.availableTemplates(for: quickActionChain, type: quickActionType)
    }

    private var enabledQuickActionIDs: [String] {
        let available = quickActionTemplates.map(\.id)
        let defaults = QuickActionCatalog.defaultTemplateIDs(for: quickActionChain, type: quickActionType)
        return store.settings.enabledQuickActionIDs(
            for: quickActionChain,
            type: quickActionType,
            availableIDs: available,
            defaultIDs: defaults
        )
    }

    var body: some View {
        HStack(spacing: 14) {
            sidebar
            contentPane
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            syncTTLFromSettings()
            reloadInstalledApps()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ChainPad Settings")
                .font(.headline)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            sidebarButton(.general, title: "General", icon: "gearshape.fill")
            sidebarButton(.quickActions, title: "Quick Actions", icon: "bolt.circle")
            sidebarButton(.apps, title: "Apps", icon: "square.grid.2x2")

            Spacer(minLength: 8)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit App", systemImage: "power.circle.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.10))
            )
            .nativeToolTip("Quit App")
        }
        .padding(12)
        .frame(width: 245)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }

    private var contentPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch selectedTab {
                case .general:
                    generalTab
                case .quickActions:
                    quickActionsTab
                case .apps:
                    appsTab
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingsCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Capture")
                            .font(.headline)
                        Text("Pause clipboard monitoring instantly.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $store.settings.capturePaused)
                        .labelsHidden()
                }
            }

            settingsCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Launch")
                            .font(.headline)
                        Text("Automatically open the app on launch.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $store.settings.autoOpenOnLaunch)
                        .labelsHidden()
                }
            }

            settingsCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Retention")
                        .font(.headline)

                    LazyVGrid(columns: compactTTLColumns, spacing: 6) {
                        ttlButton(.h8)
                        ttlButton(.h24)
                        ttlButton(.h72)
                        ttlButton(.custom)
                        ttlButton(.never)
                    }

                    if selectedTTL == .custom {
                        HStack(spacing: 8) {
                            TextField("Hours", text: $customTTLInput)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 110)

                            iconButton(systemName: "checkmark.circle.fill", helpText: "Apply Custom TTL") {
                                applyCustomTTL()
                            }
                        }

                        Text("Choose how long non-pinned session items are kept.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if selectedTTL == .never {
                        Text("Session items never expire automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var quickActionsTab: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Actions")
                    .font(.headline)

                Text("Choose which action buttons appear per chain and address type.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    selectorMenu(
                        title: "Chain",
                        value: quickActionChain.displayName,
                        menuItems: Chain.allCases.map(\.displayName),
                        selectedIndex: Chain.allCases.firstIndex(of: quickActionChain) ?? 0
                    ) { index in
                        quickActionChain = Chain.allCases[index]
                    }

                    selectorMenu(
                        title: "Address Type",
                        value: quickActionType.displayName,
                        menuItems: CryptoObjectType.allCases.map(\.displayName),
                        selectedIndex: CryptoObjectType.allCases.firstIndex(of: quickActionType) ?? 0
                    ) { index in
                        quickActionType = CryptoObjectType.allCases[index]
                    }

                    Spacer()

                    iconButton(systemName: "arrow.uturn.backward.circle", helpText: "Reset to Defaults") {
                        resetQuickActionsForSelection()
                    }
                }

                if quickActionTemplates.isEmpty {
                    Text("No actions available for this selection.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(quickActionTemplates, id: \.id) { template in
                            Toggle(isOn: Binding(
                                get: { isQuickActionEnabled(templateID: template.id) },
                                set: { setQuickActionEnabled($0, templateID: template.id) }
                            )) {
                                Label(template.label, systemImage: iconForQuickAction(template.id))
                                    .labelStyle(.titleAndIcon)
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .listStyle(.inset)
                    .frame(height: 500)
                }

                Text("Changes apply to new captures and existing items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appsTab: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("App Tracking")
                    .font(.headline)

                Text("Checked apps are tracked. Uncheck apps you don't want to detect copies from.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField("Search installed apps", text: $appSearchQuery)
                        .textFieldStyle(.roundedBorder)

                    iconButton(systemName: "arrow.clockwise", helpText: "Reload Installed Apps") {
                        reloadInstalledApps()
                    }
                }

                if isLoadingInstalledApps {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading installed apps...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if filteredApps.isEmpty, !isLoadingInstalledApps {
                    Text(installedApps.isEmpty ? "No installed apps found." : "No apps match your search.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(filteredApps) { app in
                            Toggle(isOn: Binding(
                                get: { isTracked(bundleID: app.bundleID) },
                                set: { setTracked($0, bundleID: app.bundleID) }
                            )) {
                                HStack(spacing: 10) {
                                    AppIconView(appPath: app.appPath)
                                    Text(app.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .listStyle(.inset)
                    .frame(height: 440)

                    Text("\(trackedCount) tracked • \(ignoredCount) ignored")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup("Add app manually (advanced)", isExpanded: $showManualAppEntry) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Use this only when an app is missing from the installed list.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            TextField("Bundle ID (example: com.apple.Safari)", text: $newBundleID)
                                .textFieldStyle(.roundedBorder)

                            iconButton(systemName: "plus.circle.fill", helpText: "Add Bundle ID") {
                                let trimmed = newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                store.settings.addBlacklist(bundleID: trimmed)
                                newBundleID = ""
                            }
                        }

                        if !manuallyIgnoredBundleIDs.isEmpty {
                            Text("Manual ignored bundle IDs")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(manuallyIgnoredBundleIDs, id: \.self) { bundleID in
                                HStack {
                                    Text(bundleID)
                                        .font(.caption.monospaced())
                                        .lineLimit(1)
                                    Spacer()
                                    iconButton(systemName: "xmark.circle", helpText: "Remove \(bundleID)") {
                                        store.settings.removeBlacklist(bundleID: bundleID)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func sidebarButton(_ tab: SettingsTab, title: String, icon: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(selectedTab == tab ? Color.accentColor : Color.clear)
        )
        .foregroundStyle(selectedTab == tab ? Color.white : Color.primary)
    }

    private func selectorMenu(
        title: String,
        value: String,
        menuItems: [String],
        selectedIndex: Int,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Menu {
                ForEach(menuItems.indices, id: \.self) { index in
                    Button {
                        onSelect(index)
                    } label: {
                        if index == selectedIndex {
                            Label(menuItems[index], systemImage: "checkmark")
                        } else {
                            Text(menuItems[index])
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(value)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .frame(width: 190, height: 32, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.16))
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func ttlButton(_ option: TTLSelection) -> some View {
        Button {
            selectTTL(option)
        } label: {
            Text(option.rawValue)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(selectedTTL == option ? Color.accentColor : Color.secondary.opacity(0.14))
                )
                .foregroundStyle(selectedTTL == option ? Color.white : Color.primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconButton(systemName: String, helpText: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 16, height: 16)
                .padding(6)
                .accessibilityLabel(helpText)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .nativeToolTip(helpText)
    }

    private func selectTTL(_ option: TTLSelection) {
        selectedTTL = option

        switch option {
        case .h8:
            store.settings.sessionTTLHours = 8
        case .h24:
            store.settings.sessionTTLHours = 24
        case .h72:
            store.settings.sessionTTLHours = 72
        case .never:
            store.settings.sessionTTLHours = 0
        case .custom:
            if store.settings.sessionTTLHours > 0,
               store.settings.sessionTTLHours != 8,
               store.settings.sessionTTLHours != 24,
               store.settings.sessionTTLHours != 72 {
                customTTLInput = String(Int(store.settings.sessionTTLHours))
            }
        }
    }

    private func applyCustomTTL() {
        let trimmed = customTTLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let hours = Double(trimmed), hours > 0 else { return }
        store.settings.sessionTTLHours = hours
        selectedTTL = .custom
    }

    private func syncTTLFromSettings() {
        let ttl = store.settings.sessionTTLHours
        if ttl == 0 {
            selectedTTL = .never
        } else if ttl == 8 {
            selectedTTL = .h8
        } else if ttl == 24 {
            selectedTTL = .h24
        } else if ttl == 72 {
            selectedTTL = .h72
        } else {
            selectedTTL = .custom
            customTTLInput = String(Int(ttl))
        }
    }

    private func isTracked(bundleID: String) -> Bool {
        !store.settings.blacklistedBundleIDs.contains(bundleID)
    }

    private func setTracked(_ tracked: Bool, bundleID: String) {
        if tracked {
            store.settings.removeBlacklist(bundleID: bundleID)
        } else {
            store.settings.addBlacklist(bundleID: bundleID)
        }
    }

    private func isQuickActionEnabled(templateID: String) -> Bool {
        enabledQuickActionIDs.contains(templateID)
    }

    private func setQuickActionEnabled(_ enabled: Bool, templateID: String) {
        let available = quickActionTemplates.map(\.id)
        var current = enabledQuickActionIDs

        if enabled {
            if !current.contains(templateID) {
                current.append(templateID)
            }
        } else {
            current.removeAll { $0 == templateID }
        }

        current = available.filter { current.contains($0) }
        store.settings.setEnabledQuickActionIDs(current, for: quickActionChain, type: quickActionType)
        store.applyQuickActionPreferencesToExistingItems()
    }

    private func resetQuickActionsForSelection() {
        store.settings.resetQuickActionIDs(for: quickActionChain, type: quickActionType)
        store.applyQuickActionPreferencesToExistingItems()
    }

    private func iconForQuickAction(_ templateID: String) -> String {
        switch templateID {
        case "chart": return "chart.line.uptrend.xyaxis"
        case "swap": return "arrow.left.arrow.right"
        case "explorer": return "globe"
        case "bubblemaps": return "circle.grid.3x3.fill"
        case "copy": return "doc.on.doc"
        case "dexscreener": return "waveform.path.ecg"
        case "dextools": return "hammer.fill"
        case "birdeye": return "eye.fill"
        case "gmgn": return "bolt.fill"
        case "photon": return "sun.max.fill"
        case "solscan", "etherscan", "basescan", "arbiscan", "bscscan", "polygonscan": return "magnifyingglass"
        case "open": return "arrow.up.forward.square"
        default: return "square.grid.2x2"
        }
    }

    private func reloadInstalledApps() {
        isLoadingInstalledApps = true

        Task {
            let apps = await Task.detached(priority: .userInitiated) {
                Self.discoverInstalledApps()
            }.value

            installedApps = apps
            isLoadingInstalledApps = false
        }
    }

    nonisolated private static func discoverInstalledApps() -> [AppOption] {
        let fileManager = FileManager.default
        let roots = [
            "/Applications",
            "/System/Applications",
            NSString(string: "~/Applications").expandingTildeInPath,
        ]

        var byBundleID: [String: AppOption] = [:]

        for root in roots {
            let rootURL = URL(fileURLWithPath: root, isDirectory: true)
            guard fileManager.fileExists(atPath: rootURL.path) else { continue }

            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles],
                errorHandler: nil
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard url.pathExtension.lowercased() == "app" else { continue }
                enumerator.skipDescendants()

                guard let bundle = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier,
                      !bundleID.isEmpty else {
                    continue
                }

                let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent

                let candidate = AppOption(
                    id: bundleID,
                    name: displayName,
                    bundleID: bundleID,
                    appPath: url.path
                )

                if let existing = byBundleID[bundleID] {
                    if existing.appPath.hasPrefix("/System/") && !candidate.appPath.hasPrefix("/System/") {
                        byBundleID[bundleID] = candidate
                    }
                } else {
                    byBundleID[bundleID] = candidate
                }
            }
        }

        return byBundleID.values.sorted {
            if $0.name == $1.name {
                return $0.bundleID < $1.bundleID
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

private extension Chain {
    var displayName: String {
        switch self {
        case .solana: return "Solana"
        case .ethereum: return "Ethereum"
        case .base: return "Base"
        case .bsc: return "BSC"
        case .arbitrum: return "Arbitrum"
        case .polygon: return "Polygon"
        case .unknown: return "Unknown"
        }
    }
}

private extension CryptoObjectType {
    var displayName: String {
        switch self {
        case .token: return "Token"
        case .wallet: return "Wallet"
        case .transaction: return "Transaction"
        case .pair: return "Pair"
        case .explorerLink: return "Link"
        }
    }
}

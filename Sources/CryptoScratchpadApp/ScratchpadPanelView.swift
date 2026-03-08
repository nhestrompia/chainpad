import AppKit
import CryptoScratchpadKit
import Observation
import SwiftUI

struct ScratchpadPanelView: View {
    @Bindable var store: ScratchpadStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            TextField("Search scratchpad", text: $store.searchQuery)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if store.shouldShowSearchResults {
                        section(title: "Search Results", objects: store.searchResults)
                    } else {
                        section(title: "Pinned", objects: store.pinnedItems)
                        section(title: "Session", objects: store.sessionItems)
                    }
                }
                .padding(.bottom, 8)
            }

            if let lastErrorMessage = store.lastErrorMessage {
                Text(lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(12)
    }

    private var header: some View {
        HStack {
            Toggle("Capture", isOn: Binding(
                get: { !store.settings.capturePaused },
                set: { store.settings.capturePaused = !$0 }
            ))
            .toggleStyle(.switch)

            Spacer()

            Button("Clear Session") {
                store.clearSession()
            }
            .buttonStyle(.bordered)

            Button("Settings") {
                NSApp.keyWindow?.close()
                openSettings()
                SettingsWindowPresenter.bringToFrontSoon()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func section(title: String, objects: [CapturedObject]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if objects.isEmpty {
                Text("No items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(objects, id: \.id) { object in
                    ObjectCardView(
                        object: object,
                        onPinToggle: { selected in
                            store.setPinned(selected, pinned: !selected.isPinned)
                        },
                        onRetryEnrichment: { selected in
                            store.retryEnrichment(for: selected)
                        },
                        onRename: { selected, customName in
                            store.rename(selected, customName: customName)
                        },
                        onDelete: { selected in
                            store.delete(selected)
                        }
                    )
                }
            }
        }
    }
}

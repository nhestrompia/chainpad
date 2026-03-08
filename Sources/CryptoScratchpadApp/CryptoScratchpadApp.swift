import AppKit
import CryptoScratchpadKit
import SwiftData
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct CryptoScratchpadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let modelContainer: ModelContainer
    @State private var store: ScratchpadStore

    init() {
        let schema = Schema([
            CapturedObject.self,
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to initialize model container: \(error.localizedDescription)")
        }

        modelContainer = container

        let settings = SettingsStore()
        if settings.autoOpenOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SettingsWindowPresenter.show()
            }
        }
        let monitor = PollingClipboardMonitor(maxTextLength: 2_048, pollInterval: 0.5)
        let detector = RegexDetector()
        let quickActions = DefaultQuickActionBuilder(settings: settings)
        let validator = DefaultValidator()
        let repository = SwiftDataScratchpadRepository(context: container.mainContext)
        let enricher = DefaultEnricher(quickActionBuilder: quickActions)

        _store = State(initialValue: ScratchpadStore(
            monitor: monitor,
            detector: detector,
            validator: validator,
            enricher: enricher,
            repository: repository,
            quickActionBuilder: quickActions,
            settings: settings
        ))
    }

    var body: some Scene {
        MenuBarExtra {
            ScratchpadPanelView(store: store)
                .frame(width: 420, height: 560)
                .task {
                    store.start()
                }
        } label: {
            Text(store.menuBarLabel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsPanelView(store: store)
                .frame(width: 900, height: 760)
        }
    }
}

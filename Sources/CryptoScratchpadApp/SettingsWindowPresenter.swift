import AppKit

enum SettingsWindowPresenter {
    @MainActor
    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        bringToFrontSoon()
    }

    @MainActor
    static func bringToFrontSoon() {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard let window = settingsWindow else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.level = .normal
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    @MainActor
    private static var settingsWindow: NSWindow? {
        NSApp.windows.first { window in
            let byTitle = window.title.localizedCaseInsensitiveContains("settings")
            let byIdentifier = window.identifier?.rawValue.localizedCaseInsensitiveContains("settings") == true
            return byTitle || byIdentifier
        }
    }
}

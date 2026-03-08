import AppKit
import Foundation

@MainActor
public final class PollingClipboardMonitor: ClipboardMonitor {
    private struct SourceSnapshot {
        var bundleID: String?
        var name: String?
        var pageURL: String?
        var capturedAt: Date
    }

    private let maxTextLength: Int
    private let pollInterval: TimeInterval

    private var timer: Timer?
    private var lastChangeCount: Int
    private var continuation: AsyncStream<ClipboardEvent>.Continuation?
    private var lastExternalSource: SourceSnapshot?

    public private(set) lazy var events: AsyncStream<ClipboardEvent> = {
        AsyncStream<ClipboardEvent> { continuation in
            self.continuation = continuation
        }
    }()

    public init(maxTextLength: Int = 2_048, pollInterval: TimeInterval = 0.5) {
        self.maxTextLength = maxTextLength
        self.pollInterval = pollInterval
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    public func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollPasteboard()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func pollPasteboard() {
        let now = Date()
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        rememberExternalSourceIfNeeded(frontmostApp, at: now)

        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }

        lastChangeCount = pasteboard.changeCount

        let markerType = NSPasteboard.PasteboardType(internalCopyPasteboardMarker)
        if pasteboard.string(forType: markerType) != nil {
            return
        }

        guard let copiedText = pasteboard.string(forType: .string) else { return }
        let trimmed = copiedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxTextLength else { return }

        let source = resolveSource(frontmostApp: frontmostApp, at: now)
        let event = ClipboardEvent(
            text: trimmed,
            sourceAppBundleID: source.bundleID,
            sourceAppName: source.name,
            sourcePageURL: source.pageURL,
            frontmostAppBundleID: frontmostApp?.bundleIdentifier,
            frontmostAppName: frontmostApp?.localizedName,
            capturedAt: now
        )

        continuation?.yield(event)
    }

    private func rememberExternalSourceIfNeeded(_ app: NSRunningApplication?, at time: Date) {
        let bundleID = app?.bundleIdentifier
        let name = app?.localizedName

        guard !isLikelyInternalUtilityApp(bundleID: bundleID, name: name) else { return }

        lastExternalSource = SourceSnapshot(
            bundleID: bundleID,
            name: name,
            pageURL: lastExternalSource?.pageURL,
            capturedAt: time
        )
    }

    private func resolveSource(frontmostApp: NSRunningApplication?, at now: Date) -> SourceSnapshot {
        let current = SourceSnapshot(
            bundleID: frontmostApp?.bundleIdentifier,
            name: frontmostApp?.localizedName,
            pageURL: nil,
            capturedAt: now
        )

        let selected: SourceSnapshot
        if isLikelyInternalUtilityApp(bundleID: current.bundleID, name: current.name),
           let fallback = lastExternalSource,
           now.timeIntervalSince(fallback.capturedAt) <= 20 {
            selected = fallback
        } else {
            selected = current
        }

        let pageURL = browserPageURL(bundleID: selected.bundleID, appName: selected.name)
        let resolved = SourceSnapshot(
            bundleID: selected.bundleID,
            name: selected.name,
            pageURL: pageURL,
            capturedAt: now
        )

        if !isLikelyInternalUtilityApp(bundleID: resolved.bundleID, name: resolved.name) {
            lastExternalSource = resolved
        }

        return resolved
    }

    private func isLikelyInternalUtilityApp(bundleID: String?, name: String?) -> Bool {
        if let bundleID, bundleID == Bundle.main.bundleIdentifier {
            return true
        }

        let normalizedName = (name ?? "").lowercased()
        if normalizedName.contains("codex")
            || normalizedName.contains("cryptoscratchpad")
            || normalizedName.contains("chainpad") {
            return true
        }

        return false
    }

    private func browserPageURL(bundleID: String?, appName: String?) -> String? {
        guard let appName = resolvedBrowserAppName(bundleID: bundleID, appName: appName) else {
            return nil
        }

        let script: String
        if appName == "Safari" {
            script = #"tell application "Safari" to if (count of documents) > 0 then return URL of front document"#
        } else {
            script = #"tell application "__APP__" to if (count of windows) > 0 then return URL of active tab of front window"#
                .replacingOccurrences(of: "__APP__", with: appName)
        }

        return executeAppleScript(script)
    }

    private func resolvedBrowserAppName(bundleID: String?, appName: String?) -> String? {
        switch bundleID {
        case "com.apple.Safari":
            return "Safari"
        case "com.google.Chrome":
            return "Google Chrome"
        case "company.thebrowser.Browser":
            return "Arc"
        case "com.brave.Browser":
            return "Brave Browser"
        case "com.microsoft.edgemac":
            return "Microsoft Edge"
        default:
            guard let appName else { return nil }
            if appName == "Safari" || appName == "Google Chrome" || appName == "Arc" || appName == "Brave Browser" || appName == "Microsoft Edge" {
                return appName
            }
            return nil
        }
    }

    private func executeAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }

        var errorInfo: NSDictionary?
        let eventDescriptor = script.executeAndReturnError(&errorInfo)
        guard errorInfo == nil else {
            return nil
        }

        let value = eventDescriptor.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

import AppKit
import CryptoScratchpadKit
import Foundation
import SwiftUI

struct ObjectCardView: View {
    let object: CapturedObject
    let onPinToggle: (CapturedObject) -> Void
    let onRetryEnrichment: (CapturedObject) -> Void
    let onRename: (CapturedObject, String?) -> Void
    let onDelete: (CapturedObject) -> Void

    @Environment(\.openURL) private var openURL
    @State private var showingRenameEditor = false
    @State private var renameDraft = ""
    @State private var showCopyCheckmark = false
    @State private var copyFeedbackTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                HStack(alignment: .center, spacing: 10) {
                    tokenImageView

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(primaryTitle)
                                .font(.headline)
                                .lineLimit(1)

                            if isRenamable {
                                Button {
                                    renameDraft = object.customName ?? ""
                                    showingRenameEditor = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .frame(width: 12, height: 12)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .nativeToolTip("Rename")
                                .popover(isPresented: $showingRenameEditor, arrowEdge: .bottom) {
                                    renameEditor
                                }
                            }
                        }

                        Text(secondaryTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(identifierLine)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    if let copyAction {
                        copyButton(action: copyAction)
                    }

                    Button {
                        onRetryEnrichment(object)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .nativeToolTip(object.enrichmentState == .failed ? "Retry" : "Refetch")

                    Button(role: .destructive) {
                        onDelete(object)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                    .nativeToolTip("Delete")

                    Button {
                        onPinToggle(object)
                    } label: {
                        Image(systemName: object.isPinned ? "pin.slash" : "pin.fill")
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .nativeToolTip(object.isPinned ? "Unpin" : "Pin")
                }
            }

            if let source = object.sourceAppName {
                Text("Copied from \(source) at \(object.lastSeenAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let sourcePage = sourcePageSummary {
                Text(sourcePage)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let metadataSummary {
                Text(metadataSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !socialLinks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                        .opacity(0.28)

                    HStack(spacing: 6) {
                        ForEach(socialLinks, id: \.self) { link in
                            Button {
                                openExternalURL(link.url)
                            } label: {
                                socialIcon(for: link)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .nativeToolTip(link.label)
                        }
                    }
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 32, maximum: 36), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(nonTopActions, id: \.self) { action in
                    quickActionButton(action)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if object.enrichmentState == .queued {
                Text("Refreshing metadata...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cardBorder, lineWidth: object.isPinned ? 1.4 : 1)
        )
    }

    private var renameEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rename Item")
                .font(.headline)

            TextField("Custom label", text: $renameDraft)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            HStack {
                Button("Clear") {
                    onRename(object, nil)
                    showingRenameEditor = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    onRename(object, trimmed.isEmpty ? nil : trimmed)
                    showingRenameEditor = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(10)
    }

    private var primaryTitle: String {
        if let customName = object.customName, !customName.isEmpty {
            return customName
        }

        if let tokenName = object.metadata?.token?.name, !tokenName.isEmpty {
            return tokenName
        }

        switch object.type {
        case .token:
            return "Token"
        case .wallet:
            return "Wallet"
        case .transaction:
            return "Transaction"
        case .pair:
            return "Pair"
        case .explorerLink:
            return "Explorer Link"
        }
    }

    private var secondaryTitle: String {
        var parts = [object.type.rawValue.capitalized, object.chain.rawValue.capitalized]

        if let symbol = object.metadata?.token?.symbol, !symbol.isEmpty {
            parts.append(symbol.uppercased())
        }

        return parts.joined(separator: " • ")
    }

    private var shortIdentifier: String {
        let value = object.normalizedValue

        if let url = URL(string: value), let host = url.host() {
            let tail = url.pathComponents.last(where: { $0 != "/" }) ?? ""
            if !tail.isEmpty {
                return "\(host)/.../\(shorten(tail, head: 6, tail: 4))"
            }
            return host
        }

        if value.hasPrefix("0x") {
            return shorten(value, head: 6, tail: 4)
        }

        return shorten(value, head: 6, tail: 4)
    }

    private var copyAction: QuickActionLink? {
        object.quickActions.first(where: isCopyAction)
    }

    private var nonTopActions: [QuickActionLink] {
        object.quickActions.filter { action in
            !isCopyAction(action)
        }
    }

    private var identifierPrefix: String {
        switch object.type {
        case .token, .pair:
            return "CA"
        case .wallet:
            return "Wallet"
        case .transaction:
            return "Tx"
        case .explorerLink:
            return "Link"
        }
    }

    private var identifierLine: String {
        "\(identifierPrefix): \(shortIdentifier)"
    }

    private var isRenamable: Bool {
        if object.type == .wallet || object.type == .transaction || object.type == .pair || object.type == .explorerLink {
            return true
        }

        if object.type == .token {
            return (object.metadata?.token?.name?.isEmpty ?? true)
        }

        return false
    }

    private var metadataSummary: String? {
        switch object.type {
        case .token:
            var parts: [String] = []
            if let liquidity = object.metadata?.token?.liquidityUSD {
                parts.append("Liquidity $\(formatNumber(liquidity))")
            }
            if let marketCap = object.metadata?.token?.marketCapUSD {
                parts.append("MCap $\(formatNumber(marketCap))")
            }
            return parts.isEmpty ? nil : parts.joined(separator: " • ")
        case .wallet:
            if let balance = object.metadata?.wallet?.balance {
                return "Balance \(balance.formatted(.number.precision(.fractionLength(2))))"
            }
            return nil
        case .transaction:
            return object.metadata?.transaction?.confirmationState
        case .pair, .explorerLink:
            return nil
        }
    }

    private var sourcePageSummary: String? {
        guard let rawURL = object.sourcePageURL, let url = URL(string: rawURL), let host = url.host else {
            return nil
        }
        guard !isPrivateOrLocalHost(host) else {
            return nil
        }

        let tail = url.pathComponents.last(where: { $0 != "/" }) ?? ""
        if tail.isEmpty {
            return host
        }
        return "\(host)/.../\(shorten(tail, head: 10, tail: 6))"
    }

    @ViewBuilder
    private var tokenImageView: some View {
        if object.type == .token,
           let imageURLString = object.metadata?.token?.imageURL,
           let url = URL(string: imageURLString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 32, height: 32)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                case .failure:
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                @unknown default:
                    EmptyView()
                        .frame(width: 32, height: 32)
                }
            }
        }
    }

    private var socialLinks: [SocialLink] {
        guard object.type == .token else { return [] }
        guard let token = object.metadata?.token else { return [] }

        var links: [SocialLink] = []
        if let websiteURL = token.websiteURL, !websiteURL.isEmpty {
            links.append(SocialLink(label: "Website", icon: .website, url: websiteURL))
        }
        if let twitterURL = token.twitterURL, !twitterURL.isEmpty {
            links.append(SocialLink(label: "X / Twitter", icon: .twitter, url: twitterURL))
        }
        if let telegramURL = token.telegramURL, !telegramURL.isEmpty {
            links.append(SocialLink(label: "Telegram", icon: .telegram, url: telegramURL))
        }
        return links
    }

    private var cardBackground: some ShapeStyle {
        if object.isPinned {
            return AnyShapeStyle(Color(red: 0.96, green: 0.89, blue: 0.45).opacity(0.08))
        }
        return AnyShapeStyle(Color(NSColor.windowBackgroundColor))
    }

    private var cardBorder: Color {
        object.isPinned
            ? Color(red: 0.87, green: 0.75, blue: 0.36).opacity(0.55)
            : Color.secondary.opacity(0.2)
    }

    private func openExternalURL(_ value: String) {
        guard let url = URL(string: value) else { return }
        openURL(url)
    }

    private func run(action: QuickActionLink) {
        if action.label == "Copy" || action.url.hasPrefix("copy://") {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            let item = NSPasteboardItem()
            item.setString(object.normalizedValue, forType: .string)
            item.setString(UUID().uuidString, forType: NSPasteboard.PasteboardType(internalCopyPasteboardMarker))
            pasteboard.writeObjects([item])

            triggerCopyFeedback()
            return
        }

        guard let url = URL(string: action.url) else { return }
        openURL(url)
    }

    private func isCopyAction(_ action: QuickActionLink) -> Bool {
        action.label == "Copy" || action.url.hasPrefix("copy://")
    }

    @ViewBuilder
    private func copyButton(action: QuickActionLink) -> some View {
        Button {
            run(action: action)
        } label: {
            ZStack {
                Image(systemName: "doc.on.doc")
                    .opacity(showCopyCheckmark ? 0 : 1)
                Image(systemName: "checkmark")
                    .opacity(showCopyCheckmark ? 1 : 0)
            }
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 14, height: 14)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .nativeToolTip("Copy")
    }

    @ViewBuilder
    private func quickActionButton(_ action: QuickActionLink) -> some View {
        let tooltip = action.label
        Button {
            run(action: action)
        } label: {
            Image(systemName: actionIcon(for: action.label) ?? "square.grid.2x2")
                .frame(width: 14, height: 14)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .nativeToolTip(tooltip)
    }

    private func actionIcon(for label: String) -> String? {
        switch label.lowercased() {
        case "chart":
            return "chart.line.uptrend.xyaxis"
        case "swap":
            return "arrow.left.arrow.right"
        case "explorer", "solscan", "etherscan", "basescan", "arbiscan", "bscscan", "polygonscan":
            return "globe"
        case "bubblemaps":
            return "circle.grid.3x3.fill"
        case "dexscreener":
            return "waveform.path.ecg"
        case "dextools":
            return "hammer.fill"

        case "birdeye":
            return "eye.fill"
        case "gmgn":
            return "bolt.fill"
        case "photon":
            return "sun.max.fill"
        case "open":
            return "arrow.up.forward.square"
        default:
            return nil
        }
    }

    private func triggerCopyFeedback() {
        copyFeedbackTask?.cancel()

        withAnimation(.snappy(duration: 0.2)) {
            showCopyCheckmark = true
        }

        copyFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showCopyCheckmark = false
                }
            }
        }
    }

    private func shorten(_ text: String, head: Int, tail: Int) -> String {
        guard text.count > head + tail + 1 else { return text }
        return "\(text.prefix(head))...\(text.suffix(tail))"
    }

    private func formatNumber(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.2fB", value / 1_000_000_000)
        }
        if value >= 1_000_000 {
            return String(format: "%.2fM", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.2fK", value / 1_000)
        }
        return String(format: "%.2f", value)
    }

    private func isPrivateOrLocalHost(_ host: String) -> Bool {
        let lowercased = host.lowercased()
        if lowercased == "localhost" || lowercased == "::1" || lowercased.hasSuffix(".local") {
            return true
        }

        let parts = lowercased.split(separator: ".")
        guard parts.count == 4, parts.allSatisfy({ Int($0) != nil }) else {
            return false
        }

        let octets = parts.compactMap { Int($0) }
        guard octets.count == 4 else { return false }

        if octets[0] == 10 || octets[0] == 127 {
            return true
        }
        if octets[0] == 192, octets[1] == 168 {
            return true
        }
        if octets[0] == 172, (16...31).contains(octets[1]) {
            return true
        }

        return false
    }

    @ViewBuilder
    private func socialIcon(for link: SocialLink) -> some View {
        switch link.icon {
        case .website:
            Image(systemName: "globe")
                .frame(width: 14, height: 14)
        case .telegram:
            Image(systemName: "paperplane.circle.fill")
                .frame(width: 14, height: 14)
        case .twitter:
            Text("𝕏")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(width: 14, height: 14)
        }
    }
}

private struct SocialLink: Hashable {
    let label: String
    let icon: SocialIcon
    let url: String
}

private enum SocialIcon: Hashable {
    case website
    case twitter
    case telegram
}

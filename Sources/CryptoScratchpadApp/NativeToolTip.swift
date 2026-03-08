import AppKit
import SwiftUI

private struct NativeToolTipBridge: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.toolTip = text
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.toolTip = text
    }
}

private struct HoverHintModifier: ViewModifier {
    let text: String
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isHovering {
                    Text(text)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                        .offset(y: -28)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(1000)
                }
            }
            .zIndex(isHovering ? 1000 : 0)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovering = hovering
                }
            }
            .help(text)
            .background(
                NativeToolTipBridge(text: text)
                    .allowsHitTesting(false)
            )
    }
}

extension View {
    func nativeToolTip(_ text: String) -> some View {
        modifier(HoverHintModifier(text: text))
    }
}

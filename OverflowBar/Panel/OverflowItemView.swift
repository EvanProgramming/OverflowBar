import SwiftUI

struct OverflowItemView: View {
    let item: MenuBarItem
    let action: () -> Void
    let rightAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if let image = item.displayImage {
                    Image(nsImage: image)
                        .renderingMode(colorScheme == .dark ? .template : .original)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
                }
                else { Image(systemName: item.fallbackSymbolName).resizable().scaledToFit().padding(4).opacity(0.75) }
            }
            .frame(width: 26, height: 20)
            .padding(3)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.primary.opacity(isHovering ? 0.085 : 0))
            }
        }
        .buttonStyle(OverflowItemButtonStyle(reduceMotion: reduceMotion))
        .overlay { RightClickCaptureView(action: rightAction) }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) { isHovering = hovering }
        }
        .help(item.tooltip)
        .accessibilityLabel(item.tooltip)
    }
}

private struct RightClickCaptureView: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> RightClickView {
        let view = RightClickView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: RightClickView, context: Context) {
        nsView.action = action
    }
}

private final class RightClickView: NSView {
    var action: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent,
              event.type == .rightMouseDown || event.type == .rightMouseUp else { return nil }
        return self
    }

    override func rightMouseDown(with event: NSEvent) { action?() }
}

private struct OverflowItemButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.91 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.72),
                value: configuration.isPressed
            )
    }
}

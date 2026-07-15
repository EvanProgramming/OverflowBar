import SwiftUI

struct OverflowItemView: View {
    let item: MenuBarItem
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if let image = item.iconImage { Image(nsImage: image).resizable().scaledToFit() }
                else { Image(systemName: item.fallbackSymbolName).resizable().scaledToFit().padding(4).opacity(0.75) }
            }
            .frame(width: 28, height: 24)
            .padding(5)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.primary.opacity(isHovering ? 0.085 : 0))
            }
        }
        .buttonStyle(OverflowItemButtonStyle(reduceMotion: reduceMotion))
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) { isHovering = hovering }
        }
        .help(item.tooltip)
        .accessibilityLabel(item.tooltip)
    }
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

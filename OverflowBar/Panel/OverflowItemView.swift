import SwiftUI

struct OverflowItemView: View {
    let item: MenuBarItem
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Group {
                if let image = item.iconImage { Image(nsImage: image).resizable().scaledToFit() }
                else { Image(nsImage: NSWorkspace.shared.icon(forFile: "/Applications")).resizable().scaledToFit().opacity(0.65) }
            }.frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .padding(5)
        .help(item.tooltip)
        .accessibilityLabel(item.tooltip)
    }
}

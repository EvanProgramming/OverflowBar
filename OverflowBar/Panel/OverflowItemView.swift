import SwiftUI

struct OverflowItemView: View {
    let item: MenuBarItem
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Group {
                if let image = item.iconImage { Image(nsImage: image).resizable().scaledToFit() }
                else { Image(systemName: item.fallbackSymbolName).resizable().scaledToFit().padding(4).opacity(0.75) }
            }.frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .padding(5)
        .help(item.tooltip)
        .accessibilityLabel(item.tooltip)
    }
}

import SwiftUI

struct OverflowPanelView: View {
    @ObservedObject var store: MenuBarItemStore
    let onActivate: (MenuBarItem) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if store.selectedItems.isEmpty { Text("No menu bar items selected").foregroundStyle(.secondary).padding(.horizontal, 14) }
                ForEach(store.selectedItems) { item in OverflowItemView(item: item) { onActivate(item) } }
            }.padding(8)
        }
        .frame(height: 54)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

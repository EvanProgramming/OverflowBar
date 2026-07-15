import SwiftUI

@MainActor
final class OverflowPanelPresentationState: ObservableObject {
    @Published var isPresented = false
}

struct OverflowPanelView: View {
    @ObservedObject var store: MenuBarItemStore
    @ObservedObject var presentation: OverflowPanelPresentationState
    let onActivate: (MenuBarItem) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static var preferredHeight: CGFloat {
        if #available(macOS 26.0, *) { return 64 }
        return 58
    }

    static let itemSlotWidth: CGFloat = 46

    var body: some View {
        ZStack(alignment: .top) {
            if presentation.isPresented {
                adaptiveSurface
                    .transition(panelTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(panelAnimation, value: presentation.isPresented)
    }

    @ViewBuilder
    private var adaptiveSurface: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                panelContent
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .glassEffectTransition(.materialize)
            }
            .padding(3)
        } else {
            panelContent
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 0.5)
                }
                .padding(3)
        }
    }

    private var panelContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if store.selectedItems.isEmpty { Text("No menu bar items selected").foregroundStyle(.secondary).padding(.horizontal, 14) }
                ForEach(store.selectedItems) { item in OverflowItemView(item: item) { onActivate(item) } }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(height: Self.preferredHeight - 6)
        .scrollBounceBehavior(.basedOnSize)
    }

    private var panelTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.88, anchor: .top))
                .combined(with: .offset(y: -7)),
            removal: .opacity
                .combined(with: .scale(scale: 0.96, anchor: .top))
                .combined(with: .offset(y: -3))
        )
    }

    private var panelAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .spring(response: 0.3, dampingFraction: 0.82, blendDuration: 0.08)
    }
}

import SwiftUI

@MainActor
final class OverflowPanelPresentationState: ObservableObject {
    @Published var isPresented = false
}

struct OverflowPanelView: View {
    @ObservedObject var store: MenuBarItemStore
    @ObservedObject var presentation: OverflowPanelPresentationState
    let onActivate: (MenuBarItem) -> Void
    let onRightActivate: (MenuBarItem) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let preferredHeight: CGFloat = 46

    static let itemSlotWidth: CGFloat = 40

    var body: some View {
        ZStack(alignment: .top) {
            if presentation.isPresented {
                adaptiveSurface
                    .transition(panelTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(panelAnimation, value: presentation.isPresented)
        .saturation(0)
    }

    @ViewBuilder
    private var adaptiveSurface: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                panelContent
                    .glassEffect(.regular, in: Capsule())
                    .glassEffectTransition(.materialize)
            }
            .padding(3)
        } else {
            legacySurface
        }
    }

    private var legacySurface: some View {
        panelContent
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.16), lineWidth: 0.5)
            }
            .padding(3)
    }

    private var panelContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if store.overflowItems.isEmpty { Text("Choose icons in Menu Bar Settings to see them here.").foregroundStyle(.secondary).padding(.horizontal, 12) }
                ForEach(store.overflowItems) { item in
                    OverflowItemView(item: item, action: { onActivate(item) }, rightAction: { onRightActivate(item) })
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(height: Self.preferredHeight - 6)
        .scrollBounceBehavior(.basedOnSize)
        .help(store.lastActivationError ?? store.layoutOperationMessage ?? "Select an icon to open its menu")
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

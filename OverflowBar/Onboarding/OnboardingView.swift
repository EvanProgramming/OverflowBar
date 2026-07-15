import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: MenuBarItemStore
    @ObservedObject var permissions: PermissionManager
    let onComplete: (Bool) -> Void

    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Step = .welcome
    @State private var hideSelectedIcons: Bool

    init(
        store: MenuBarItemStore,
        permissions: PermissionManager,
        initialHideSelectedIcons: Bool,
        onComplete: @escaping (Bool) -> Void
    ) {
        self.store = store
        self.permissions = permissions
        self.onComplete = onComplete
        _hideSelectedIcons = State(initialValue: initialHideSelectedIcons)
    }

    private enum Step: Int, CaseIterable {
        case welcome, permissions, customize, ready

        var title: String {
            switch self {
            case .welcome: "Welcome"
            case .permissions: "Permissions"
            case .customize: "Customize"
            case .ready: "Ready"
            }
        }
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                progressHeader
                    .padding(.horizontal, 36)
                    .padding(.top, 24)

                ZStack {
                    stepContent
                        .id(step)
                        .transition(stepTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                navigation
                    .padding(.horizontal, 36)
                    .padding(.bottom, 28)
            }
        }
        .frame(minWidth: 680, minHeight: 500)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.42, dampingFraction: 0.86), value: step)
        .task {
            while !Task.isCancelled {
                permissions.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onChange(of: permissions.accessibilityGranted) { _, granted in
            if granted && store.items.isEmpty { store.refresh() }
        }
        .onChange(of: step) { _, newStep in
            if newStep == .customize { store.refresh() }
        }
        .alert("Launch at Login", isPresented: Binding(
            get: { launchAtLogin.errorMessage != nil },
            set: { _ in }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(launchAtLogin.errorMessage ?? "Unable to update the login item.")
        }
    }

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [Color.accentColor.opacity(0.14), .clear, Color.cyan.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.accentColor.opacity(0.09))
                .frame(width: 360, height: 360)
                .blur(radius: 70)
                .offset(x: 300, y: -230)
        }
        .ignoresSafeArea()
    }

    private var progressHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Step.allCases, id: \.rawValue) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(width: item == step ? 28 : 8, height: 8)
                }
            }
            Spacer()
            Text("\(step.rawValue + 1) of \(Step.allCases.count)  ·  \(step.title)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome: welcomeStep
        case .permissions: permissionsStep
        case .customize: customizeStep
        case .ready: readyStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 22) {
            overflowLogo
            VStack(spacing: 9) {
                Text("Make room for what matters")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                Text("OverflowBar keeps a clean menu bar and brings hidden controls back in one fluid row.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 540)
            }
            HStack(spacing: 12) {
                featureChip("menubar.rectangle", "Clean menu bar")
                featureChip("hand.tap", "Click-through controls")
                featureChip("macbook", "Notch-aware")
            }
        }
        .padding(36)
    }

    private var permissionsStep: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("Two permissions, clearly explained")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("OverflowBar only uses these permissions to find, display, and activate your menu bar controls.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }

            VStack(spacing: 12) {
                PermissionCard(
                    icon: "accessibility",
                    title: "Accessibility",
                    detail: "Finds menu bar controls and triggers their normal click action.",
                    isGranted: permissions.accessibilityGranted,
                    request: permissions.requestAccessibility,
                    openSettings: permissions.openAccessibilitySettings
                )
                PermissionCard(
                    icon: "rectangle.inset.filled.and.person.filled",
                    title: "Screen Recording",
                    detail: "Captures only the small icon regions used in the overflow row.",
                    isGranted: permissions.screenRecordingGranted,
                    request: permissions.requestScreenRecording,
                    openSettings: permissions.openScreenRecordingSettings
                )
            }
            .frame(maxWidth: 610)
        }
        .padding(32)
    }

    private var customizeStep: some View {
        VStack(spacing: 18) {
            VStack(spacing: 7) {
                Text("Make OverflowBar yours")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("Choose what moves into the overflow row. You can change this anytime.")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                Toggle("Open OverflowBar at Login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .padding(.horizontal, 18)
                .padding(.vertical, 13)

                Divider().padding(.leading, 18)

                Toggle("Hide selected icons from the original menu bar", isOn: $hideSelectedIcons)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
            }
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .frame(maxWidth: 610)

            VStack(spacing: 10) {
                HStack {
                    Text("Menu Bar Items").font(.headline)
                    Spacer()
                    Button("Refresh") { store.refresh() }
                    Button("Select All") { store.selectAll(true) }
                        .disabled(store.items.isEmpty)
                }
                if store.items.isEmpty {
                    ContentUnavailableView(
                        "No Items Found",
                        systemImage: "menubar.rectangle",
                        description: Text(permissions.accessibilityGranted
                            ? "Try Refresh after your menu bar apps have opened."
                            : "Allow Accessibility first, then return here to scan.")
                    )
                    .frame(height: 122)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                            ForEach(store.items) { item in
                                itemChoice(item)
                            }
                        }
                    }
                    .frame(maxHeight: 142)
                }
            }
            .frame(maxWidth: 610)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 22)
    }

    private var readyStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Color.green.opacity(0.14)).frame(width: 104, height: 104)
                Image(systemName: "checkmark")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: step)
            }
            VStack(spacing: 8) {
                Text("OverflowBar is ready")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                Text("Use the chevron at the right side of your menu bar to reveal your new overflow row.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
            HStack(spacing: 16) {
                statusSummary("Accessibility", granted: permissions.accessibilityGranted)
                statusSummary("Screen Recording", granted: permissions.screenRecordingGranted)
                statusSummary("Selected", value: "\(store.selectedItems.count)")
            }
        }
        .padding(36)
    }

    private var navigation: some View {
        HStack {
            if step != .welcome {
                Button("Back") { move(to: step.rawValue - 1) }
                    .buttonStyle(.borderless)
            }
            Spacer()
            if step == .permissions && (!permissions.accessibilityGranted || !permissions.screenRecordingGranted) {
                Text("You can finish permissions later in Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(step == .ready ? "Start Using OverflowBar" : "Continue") {
                if step == .ready { onComplete(hideSelectedIcons) }
                else { move(to: step.rawValue + 1) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var overflowLogo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [.accentColor, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 112, height: 112)
                .shadow(color: Color.accentColor.opacity(0.28), radius: 28, y: 14)
            VStack(spacing: 7) {
                HStack(spacing: 7) {
                    ForEach(0..<4) { _ in Circle().fill(.white.opacity(0.92)).frame(width: 10, height: 10) }
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func featureChip(_ icon: String, _ title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.quaternary.opacity(0.55), in: Capsule())
    }

    private func itemChoice(_ item: MenuBarItem) -> some View {
        Toggle(isOn: Binding(
            get: { item.isSelected },
            set: { store.setSelected(item, selected: $0) }
        )) {
            HStack(spacing: 9) {
                Group {
                    if let image = item.iconImage { Image(nsImage: image).resizable().scaledToFit() }
                    else { Image(systemName: item.fallbackSymbolName) }
                }
                .frame(width: 22, height: 18)
                Text(item.title.isEmpty ? item.ownerName : item.title).lineLimit(1)
            }
        }
        .toggleStyle(.checkbox)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.quaternary.opacity(0.38), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func statusSummary(_ title: String, granted: Bool) -> some View {
        statusSummary(title, value: granted ? "Ready" : "Later", positive: granted)
    }

    private func statusSummary(_ title: String, value: String, positive: Bool = true) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline).foregroundStyle(positive ? .primary : .secondary)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: 132)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func move(to rawValue: Int) {
        guard let next = Step(rawValue: rawValue) else { return }
        step = next
    }

    private var stepTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)).combined(with: .scale(scale: 0.98)),
            removal: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.98))
        )
    }
}

private struct PermissionCard: View {
    let icon: String
    let title: String
    let detail: String
    let isGranted: Bool
    let request: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isGranted ? .green : Color.accentColor)
                .frame(width: 42, height: 42)
                .background((isGranted ? Color.green : Color.accentColor).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(title).font(.headline)
                    if isGranted {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else {
                Button("Allow", action: request).buttonStyle(.borderedProminent)
                Button(action: openSettings) { Image(systemName: "gear") }
                    .buttonStyle(.bordered)
                    .help("Open System Settings")
            }
        }
        .padding(15)
        .background(.quaternary.opacity(0.48), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

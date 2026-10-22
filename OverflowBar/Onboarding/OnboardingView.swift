import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case permissions
    case chooseIcons
}

enum OnboardingCompletion: Equatable {
    case finish(selectedIDs: [String], hideSelectedIcons: Bool)
    case setUpLater

    @MainActor func apply(to store: MenuBarItemStore) {
        guard case .finish(let selectedIDs, let hideSelectedIcons) = self else { return }
        store.configureSelection(selectedIDs, hideSelectedIcons: hideSelectedIcons)
    }
}

struct OnboardingFlowState: Equatable {
    private(set) var step: OnboardingStep = .welcome
    private(set) var selectedIDs: [String]

    init(selectedIDs: [String]) {
        self.selectedIDs = selectedIDs
    }

    mutating func advance() {
        if let next = OnboardingStep(rawValue: step.rawValue + 1) { step = next }
    }

    mutating func goBack() {
        if let previous = OnboardingStep(rawValue: step.rawValue - 1) { step = previous }
    }

    mutating func setSelected(_ id: String, selected: Bool) {
        if selected, !selectedIDs.contains(id) {
            selectedIDs.append(id)
        } else if !selected {
            selectedIDs.removeAll { $0 == id }
        }
    }

    func completion(accessibilityGranted: Bool) -> OnboardingCompletion? {
        guard accessibilityGranted || selectedIDs.isEmpty else { return nil }
        return .finish(selectedIDs: selectedIDs, hideSelectedIcons: accessibilityGranted && !selectedIDs.isEmpty)
    }

    func setUpLater() -> OnboardingCompletion { .setUpLater }
}

struct OnboardingView: View {
    @ObservedObject var store: MenuBarItemStore
    @ObservedObject var permissions: PermissionManager
    let onComplete: (OnboardingCompletion) -> Void
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @State private var flow: OnboardingFlowState

    init(store: MenuBarItemStore, permissions: PermissionManager, onComplete: @escaping (OnboardingCompletion) -> Void) {
        self.store = store
        self.permissions = permissions
        self.onComplete = onComplete
        _flow = State(initialValue: OnboardingFlowState(selectedIDs: store.selectedIDs))
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch flow.step {
                case .welcome: welcome
                case .permissions: permissionSetup
                case .chooseIcons: iconSetup
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            HStack {
                if flow.step != .welcome {
                    Button("Back") { flow.goBack() }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                }
                Spacer()
                Text("Step \(flow.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Set Up Later") { onComplete(flow.setUpLater()) }
                if flow.step != .chooseIcons {
                    Button("Continue") { flow.advance() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                } else if let completion = flow.completion(accessibilityGranted: permissions.accessibilityGranted) {
                    Button(flow.selectedIDs.isEmpty ? "Finish Setup" : "Hide Icons & Finish") {
                        onComplete(completion)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(store.nativeOperationInProgress)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .tint(.primary)
        .saturation(0)
        .frame(minWidth: 680, minHeight: 500)
        .onAppear { permissions.refresh(); launchAtLogin.refresh(); store.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.refresh()
        }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 42, weight: .regular))
                .accessibilityHidden(true)
            Text("A clearer menu bar")
                .font(.largeTitle.weight(.semibold))
            Text("Choose which icons to move into a second row. You can change your choices any time.")
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Toggle("Open OverflowBar at login", isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.setEnabled($0) }))
                .frame(maxWidth: 350, alignment: .leading)
            if let error = launchAtLogin.errorMessage {
                Label(error, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(32)
    }

    private var permissionSetup: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Permissions")
                .font(.largeTitle.weight(.semibold))
            Text("Accessibility lets OverflowBar hide selected icons and open their menus. Screen Recording adds live icon previews.")
                .foregroundStyle(.secondary)

            permissionCard(
                title: "Accessibility",
                detail: "Required to hide selected icons and open them from the second row.",
                enabled: permissions.accessibilityGranted,
                enable: permissions.requestAccessibility,
                openSettings: permissions.openAccessibilitySettings
            )
            permissionCard(
                title: "Screen Recording",
                detail: "Optional. Shows live icons instead of available app icons.",
                enabled: permissions.screenRecordingGranted,
                enable: permissions.requestScreenRecording,
                openSettings: permissions.openScreenRecordingSettings
            )

            if !permissions.accessibilityGranted {
                Label("You can set up OverflowBar later without changing your current icons.", systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 470, alignment: .leading)
        .padding(32)
    }

    private var iconSetup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose Icons")
                    .font(.largeTitle.weight(.semibold))
                Text("Select the icons you want in the second row. Your changes are saved when you finish setup.")
                    .foregroundStyle(.secondary)
                if !permissions.accessibilityGranted, !flow.selectedIDs.isEmpty {
                    Label("Enable Accessibility to apply this selection. Choose Set Up Later to keep your current setup unchanged.", systemImage: "hand.raised")
                        .font(.callout).foregroundStyle(.secondary)
                }
                MenuBarIconSelectionList(
                    items: store.items,
                    selectedIDs: Set(flow.selectedIDs),
                    allowsSelection: !store.nativeOperationInProgress,
                    onRefresh: { store.refresh() },
                    onSelectionChange: { flow.setSelected($0.id, selected: $1) }
                )
            }
            .padding(24)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func permissionCard(title: String, detail: String, enabled: Bool, enable: @escaping () -> Void, openSettings: @escaping () -> Void) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(detail).font(.callout).foregroundStyle(.secondary)
                HStack {
                    Label(enabled ? "Enabled" : "Not enabled", systemImage: enabled ? "checkmark.circle" : "circle")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !enabled {
                        Button("Enable", action: enable)
                        Button("Open System Settings", action: openSettings)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title)
        }
    }
}

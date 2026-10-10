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
        VStack(spacing: 0) {
            progressHeader
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 12)

            ScrollView {
                stepContent
                    .id(step)
                    .transition(stepTransition)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            navigation
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
        }
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .frame(minWidth: 680, minHeight: 500)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.42, dampingFraction: 0.86), value: step)
        .task {
            while !Task.isCancelled {
                permissions.refresh()
                try? await Task.sleep(for: .seconds(2))
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

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(step.title).font(.headline)
                Spacer()
                Text("Step \(step.rawValue + 1) of \(Step.allCases.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(step.rawValue + 1), total: Double(Step.allCases.count))
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
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 92, height: 92)
                .accessibilityLabel("OverflowBar app icon")

            VStack(spacing: 8) {
                Text("Welcome to OverflowBar")
                    .font(.largeTitle.weight(.semibold))
                Text("Keep a tidy menu bar and bring selected status items back in a compact second row.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }

    private var permissionsStep: some View {
        Form {
            Section("Accessibility") {
                Text("Finds menu bar controls and activates their normal click action.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                permissionStatusRow(
                    title: "Accessibility",
                    symbol: "accessibility",
                    detail: permissions.accessibilityGranted ? "Allowed" : "Not Allowed",
                    isGranted: permissions.accessibilityGranted,
                    request: permissions.requestAccessibility,
                    openSettings: permissions.openAccessibilitySettings
                )
            }
            Section("Screen Recording") {
                Text("Captures only the small icon regions used in the overflow row.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                permissionStatusRow(
                    title: "Screen Recording",
                    symbol: "rectangle.inset.filled.and.person.filled",
                    detail: permissions.screenRecordingGranted ? "Allowed" : "Not Allowed",
                    isGranted: permissions.screenRecordingGranted,
                    request: permissions.requestScreenRecording,
                    openSettings: nil,
                    requestTitle: "Open Settings"
                )
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 640)
        .padding(.vertical, 18)
    }

    private var customizeStep: some View {
        Form {
            Section("Options") {
                Toggle("Open OverflowBar at Login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                Toggle("Hide selected icons from the original menu bar", isOn: $hideSelectedIcons)
            }
            Section("Menu Bar Items") {
                HStack {
                    Text("Choose what moves into the overflow row.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") { store.refresh() }
                    Button("Select All") { store.selectAll(true) }
                        .disabled(store.items.isEmpty)
                }
                if let message = store.iconCaptureMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                if store.items.isEmpty {
                    ContentUnavailableView(
                        "No Items Found",
                        systemImage: "menubar.rectangle",
                        description: Text(permissions.accessibilityGranted
                            ? "Try Refresh after your menu bar apps have opened."
                            : "Allow Accessibility first, then return here to scan.")
                    )
                } else {
                    ForEach(store.items) { item in itemChoice(item) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 640)
        .padding(.vertical, 8)
    }

    private var readyStep: some View {
        VStack(spacing: 18) {
            Label("OverflowBar is ready", systemImage: "checkmark.circle.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.green)
            Text("Use the chevron at the right side of your menu bar to reveal your overflow row.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            VStack(alignment: .leading, spacing: 8) {
                statusSummary("Accessibility", granted: permissions.accessibilityGranted)
                statusSummary("Screen Recording", granted: permissions.screenRecordingGranted)
                Label("\(store.selectedItems.count) selected items", systemImage: "menubar.rectangle")
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var navigation: some View {
        HStack {
            if step != .welcome {
                Button("Back") { move(to: step.rawValue - 1) }
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

    private func permissionStatusRow(
        title: String,
        symbol: String,
        detail: String,
        isGranted: Bool,
        request: @escaping () -> Void,
        openSettings: (() -> Void)?,
        requestTitle: String = "Allow"
    ) -> some View {
        HStack(spacing: 12) {
            Label(title, systemImage: symbol)
            Spacer()
            if isGranted {
                Label(detail, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(requestTitle, action: request)
                    .buttonStyle(.borderedProminent)
                if let openSettings {
                    Button("Open Settings", action: openSettings)
                }
            }
        }
    }

    private func itemChoice(_ item: MenuBarItem) -> some View {
        Toggle(isOn: Binding(
            get: { item.isSelected },
            set: { store.setSelected(item, selected: $0) }
        )) {
            HStack(spacing: 9) {
                Group {
                    if let image = item.displayImage { Image(nsImage: image).resizable().scaledToFit() }
                    else { Image(systemName: item.fallbackSymbolName) }
                }
                .frame(width: 22, height: 18)
                Text(item.title.isEmpty ? item.ownerName : item.title)
                    .lineLimit(1)
            }
        }
        .toggleStyle(.checkbox)
    }

    @ViewBuilder
    private func statusSummary(_ title: String, granted: Bool) -> some View {
        if granted {
            Label(title, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            Label(title, systemImage: "exclamationmark.circle").foregroundStyle(.secondary)
        }
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

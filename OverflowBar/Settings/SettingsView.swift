import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case menuBar = "Menu Bar"
    case behavior = "Behavior"
    case permissions = "Permissions"
    case about = "About"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .menuBar: "menubar.rectangle"
        case .behavior: "slider.horizontal.3"
        case .permissions: "hand.raised"
        case .about: "info.circle"
        }
    }
}

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var selection: SettingsSection = .menuBar
}

struct SettingsView: View {
    @ObservedObject var store: MenuBarItemStore
    @ObservedObject var permissions: PermissionManager
    @ObservedObject var navigation: SettingsNavigation
    var showOnboarding: () -> Void = {}
    var checkForUpdates: () -> Void = {}
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @AppStorage("hoverRevealEnabled") private var hoverRevealEnabled = false
    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.selection) {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.symbol)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 180)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(.background)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { store.onShowPanelRequested?() }) {
                    Label("Open OverflowBar", systemImage: "chevron.down.circle")
                }
            }
            ToolbarItem {
                Menu {
                    Button("Refresh Icons", systemImage: "arrow.clockwise") { store.refresh() }
                    Button("Reveal Icons", systemImage: "eye") { store.revealOriginals() }
                    Divider()
                    Button("Reset Icon Selection…", systemImage: "trash", role: .destructive) {
                        showingResetConfirmation = true
                    }
                    .disabled(store.nativeOperationInProgress)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Reset Icon Selection?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
            Button("Reset Icon Selection", role: .destructive) { store.restoreAllAndDisable() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears your saved selection and shows all menu bar icons again.")
        }
        .tint(.primary)
        .frame(minWidth: 760, minHeight: 540)
        .onAppear { permissions.refresh(); launchAtLogin.refresh(); store.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.refresh()
        }
        .alert("OverflowBar", isPresented: Binding(get: { store.lastActivationError != nil }, set: { if !$0 { store.lastActivationError = nil } })) {
            Button("OK", role: .cancel) { store.lastActivationError = nil }
        } message: { Text(store.lastActivationError ?? "") }
    }

    @ViewBuilder
    private var detail: some View {
        switch navigation.selection {
        case .menuBar:
            menuBarSection
        case .behavior:
            behaviorSection
        case .permissions:
            permissionsSection
        case .about:
            aboutSection
        }
    }

    private var menuBarSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heading("Menu Bar", detail: "Choose which icons to keep in OverflowBar.")

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Hide selected icons", isOn: Binding(
                            get: { store.layoutManagementEnabled },
                            set: { store.setLayoutManagementEnabled($0) }
                        ))
                        .disabled(store.nativeOperationInProgress || (store.selectedIDs.isEmpty && !store.layoutManagementEnabled) || !permissions.accessibilityGranted && !store.layoutManagementEnabled)

                        Label(visibilityDescription, systemImage: store.groupHidden ? "checkmark.circle" : "circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Second Row", systemImage: "rectangle.stack")
                }

                if !permissions.accessibilityGranted {
                    Label("Enable Accessibility to select, hide, or open menu bar icons.", systemImage: "hand.raised")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                MenuBarIconSelectionList(
                    items: store.items,
                    selectedIDs: Set(store.selectedIDs),
                    allowsSelection: !store.nativeOperationInProgress && permissions.accessibilityGranted,
                    onRefresh: { store.refresh() },
                    onSelectionChange: { store.setSelected($0, selected: $1) }
                )

                if let progress = store.operationProgress {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(progress).font(.callout)
                        Spacer()
                        Button("Cancel") { store.cancelOperation() }
                    }
                }
                if let message = store.layoutOperationMessage {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
                if let message = store.iconCaptureMessage {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: 660, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var behaviorSection: some View {
        Form {
            Section("When OverflowBar Opens") {
                Toggle("Open at login", isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.setEnabled($0) }))
                Toggle("Show the second row when the pointer enters the menu bar", isOn: $hoverRevealEnabled)
                if let error = launchAtLogin.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.secondary)
                }
            }
            Section("Setup") {
                Button("Run Setup Again", action: showOnboarding)
                Button("Quit OverflowBar", role: .destructive) { NSApp.terminate(nil) }
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }

    private var permissionsSection: some View {
        Form {
            Section("Accessibility") {
                Text("Allows OverflowBar to hide selected icons and open their menus.")
                    .font(.callout).foregroundStyle(.secondary)
                permissionRow("Accessibility", granted: permissions.accessibilityGranted, open: permissions.openAccessibilitySettings, request: permissions.requestAccessibility)
            }
            Section("Screen Recording") {
                Text("Shows live menu bar icons in the second row. Without this access, OverflowBar uses available app icons.")
                    .font(.callout).foregroundStyle(.secondary)
                permissionRow("Screen Recording", granted: permissions.screenRecordingGranted, open: permissions.openScreenRecordingSettings, request: permissions.requestScreenRecording)
            }
            Section {
                Button("Refresh Permission Status", systemImage: "arrow.clockwise") { permissions.refresh() }
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }

    private var aboutSection: some View {
        Form {
            Section("OverflowBar") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                Text("Keep your menu bar tidy and open selected icons from one place.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Updates") {
                Button("Check for Updates…", action: checkForUpdates)
                Text("OverflowBar checks for updates and asks before installing them.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Acknowledgements") {
                Text("OverflowBar's menu bar engine includes work from Ice and Thaw. The project and third-party licenses are available on GitHub.")
                    .font(.callout).foregroundStyle(.secondary)
                Link("Third-Party Notices", destination: URL(string: "https://github.com/EvanProgramming/OverflowBar/blob/Evan/v1.5-stability/THIRD_PARTY_NOTICES.md")!)
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }

    private var visibilityDescription: String {
        if store.groupHidden { return "Selected icons are hidden. Open OverflowBar to use them." }
        if store.nativeOperationInProgress { return "Moving selected icons to the second row." }
        if store.layoutManagementEnabled && !permissions.accessibilityGranted { return "Enable Accessibility to hide selected icons." }
        return "Selected icons stay in the menu bar."
    }

    private func heading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.largeTitle.weight(.semibold))
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func permissionRow(_ name: String, granted: Bool, open: @escaping () -> Void, request: @escaping () -> Void) -> some View {
        HStack {
            Label(granted ? "Enabled" : "Not enabled", systemImage: granted ? "checkmark.circle" : "circle")
                .foregroundStyle(.secondary)
            Spacer()
            if !granted {
                Button("Enable", action: request)
                Button("Open System Settings", action: open)
            }
        }
    }
}

struct MenuBarIconSelectionList: View {
    let items: [MenuBarItem]
    let selectedIDs: Set<String>
    let allowsSelection: Bool
    let onRefresh: () -> Void
    let onSelectionChange: (MenuBarItem, Bool) -> Void

    var body: some View {
        GroupBox {
            VStack(spacing: 0) {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label("No Menu Bar Icons", systemImage: "menubar.rectangle")
                    } description: {
                        Text("Open an app with a menu bar icon, then refresh the list.")
                    } actions: {
                        Button("Refresh Icons", action: onRefresh)
                    }
                    .padding(.vertical, 12)
                } else {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            icon(for: item)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.ownerName).lineLimit(1)
                                Text(selectionNote(for: item))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 12)
                            Toggle("Hide", isOn: Binding(
                                get: { selectedIDs.contains(item.id) },
                                set: { onSelectionChange(item, $0) }
                            ))
                            .labelsHidden()
                            .accessibilityLabel("Hide \(item.ownerName)")
                            .disabled(!allowsSelection || item.isProtectedSystemItem || item.nativeRecord?.persistentID == nil)
                        }
                        .padding(.vertical, 7)
                        if item.id != items.last?.id { Divider() }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Menu Bar Icons", systemImage: "menubar.rectangle")
        }
    }

    @ViewBuilder private func icon(for item: MenuBarItem) -> some View {
        if let image = item.displayImage {
            Image(nsImage: image)
                .renderingMode(item.usesTemplateIcon ? .template : .original)
                .resizable().scaledToFit().frame(width: 24, height: 22)
                .saturation(0)
                .foregroundStyle(Color.primary)
        } else {
            Image(systemName: item.fallbackSymbolName)
                .frame(width: 24, height: 22)
                .saturation(0)
                .foregroundStyle(.primary)
        }
    }

    private func selectionNote(for item: MenuBarItem) -> String {
        if item.isProtectedSystemItem { return "Managed by macOS" }
        if item.nativeRecord?.persistentID == nil { return "Unavailable" }
        return item.tooltip
    }
}

import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: MenuBarItemStore
    var showOnboarding: () -> Void = {}
    var checkForUpdates: () -> Void = {}
    @StateObject private var permissions = PermissionManager()
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @AppStorage("hoverRevealEnabled") private var hoverRevealEnabled = true

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gearshape") }
            menuBarSettings
                .tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }
            permissionsSettings
                .tabItem { Label("Permissions", systemImage: "hand.raised") }
        }
        .frame(minWidth: 620, minHeight: 460)
        .onAppear { permissions.refresh(); launchAtLogin.refresh(); store.refresh() }
        .alert("OverflowBar", isPresented: Binding(get: { store.lastActivationError != nil }, set: { if !$0 { store.lastActivationError = nil } })) {
            Button("OK", role: .cancel) { store.lastActivationError = nil }
        } message: {
            Text(store.lastActivationError ?? "")
        }
    }

    private var generalSettings: some View {
        Form {
            Section("General") {
                Toggle("Open OverflowBar at Login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                Toggle("Reveal when the pointer reaches the menu bar", isOn: $hoverRevealEnabled)
                if let error = launchAtLogin.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
            Section("Updates") {
                LabeledContent("Version", value: appVersion)
                Button("Check for Updates…", action: checkForUpdates)
                Text("OverflowBar checks periodically and asks before installing updates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Advanced") {
                Button("Run Welcome Setup Again", action: showOnboarding)
                Button("Quit OverflowBar", role: .destructive) { NSApp.terminate(nil) }
            }
        }
        .formStyle(.grouped)
    }

    private var menuBarSettings: some View {
        Form {
            Section("Menu Bar Layout") {
                Toggle("Hide selected original icons", isOn: Binding(
                    get: { store.layoutManagementEnabled },
                    set: { store.setLayoutManagementEnabled($0) }
                ))
                Text("OverflowBar keeps the original menu-bar order while the hidden layout is applied. Items move only after you enable this setting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if #available(macOS 27.0, *) {
                    Text("macOS 27 uses a unified menu-bar host. Items the system does not expose individually remain under the native overflow control.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Apply Hidden Layout") { store.applyLayout() }
                        .disabled(!store.layoutManagementEnabled || store.selectedItems.isEmpty)
                    Button("Restore All Managed Icons") { store.restoreLayout() }
                        .disabled(store.selectedItems.isEmpty)
                    Button("Safe Reset", role: .destructive) { store.restoreAllAndDisable() }
                }
                if let message = store.layoutOperationMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Menu Bar Items") {
                HStack {
                    Text("Choose the items to manage")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") { store.refresh() }
                    Button("Select All") { store.selectAll(true) }
                        .disabled(store.items.isEmpty)
                    Button("Deselect All") { store.selectAll(false) }
                        .disabled(store.items.isEmpty)
                }
                if let message = store.iconCaptureMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                if !permissions.accessibilityGranted {
                    Text("Enable Accessibility to scan and activate menu bar items.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.items) { item in
                    Toggle(isOn: Binding(
                        get: { item.isSelected },
                        set: { store.setSelected(item, selected: $0) }
                    )) {
                        HStack {
                            icon(for: item)
                            VStack(alignment: .leading) {
                                Text(item.ownerName)
                                Text(item.title).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if item.isAlwaysVisibleSystemItem {
                                Text("System · always visible")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if item.isProtectedSystemItem {
                                Text("System · configurable")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: item.activationStatusSymbolName)
                                    .help(item.activationStatusHelp)
                            }
                        }
                    }
                    .disabled(item.isAlwaysVisibleSystemItem)
                }
                if permissions.accessibilityGranted && store.items.isEmpty {
                    Text("No accessible right-side menu bar items were found. Some apps do not expose status items to Accessibility.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var permissionsSettings: some View {
        Form {
            Section("Permissions") {
                permissionRow("Accessibility", granted: permissions.accessibilityGranted, open: permissions.openAccessibilitySettings, request: permissions.requestAccessibility)
                permissionRow("Screen Recording", granted: permissions.screenRecordingGranted, open: permissions.openScreenRecordingSettings, request: permissions.requestScreenRecording)
                Button("Refresh Permission Status") { permissions.refresh() }
            }
        }
        .formStyle(.grouped)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    @ViewBuilder private func permissionRow(_ name: String, granted: Bool, open: @escaping () -> Void, request: @escaping () -> Void) -> some View {
        HStack {
            Label("\(name): \(granted ? "Granted" : "Not Granted")", systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
            Spacer()
            if !granted {
                Button("Open \(name) Settings", action: open)
                Button("Request", action: request)
            }
        }
    }

    @ViewBuilder private func icon(for item: MenuBarItem) -> some View {
        if let image = item.displayImage {
            Image(nsImage: image)
                .renderingMode(item.usesTemplateIcon ? .template : .original)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.primary)
                .frame(width: 24, height: 20)
        } else {
            Image(systemName: "menubar.rectangle").frame(width: 24)
        }
    }
}

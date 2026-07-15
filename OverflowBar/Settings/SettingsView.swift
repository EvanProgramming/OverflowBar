import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: MenuBarItemStore
    var showOnboarding: () -> Void = {}
    @StateObject private var permissions = PermissionManager()
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @AppStorage("hoverRevealEnabled") private var hoverRevealEnabled = true

    var body: some View {
        Form {
            Section("General") {
                Toggle("Open OverflowBar at Login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                Toggle("Reveal when the pointer reaches the menu bar", isOn: $hoverRevealEnabled)
                Button("Run Welcome Setup Again", action: showOnboarding)
                Button("Quit OverflowBar", role: .destructive) { NSApp.terminate(nil) }
                if let error = launchAtLogin.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            Section("Permissions") {
                permissionRow("Accessibility", granted: permissions.accessibilityGranted, open: permissions.openAccessibilitySettings, request: permissions.requestAccessibility)
                permissionRow("Screen Recording", granted: permissions.screenRecordingGranted, open: permissions.openScreenRecordingSettings, request: permissions.requestScreenRecording)
                Button("Refresh Permission Status") { permissions.refresh() }
            }
            Section("Menu Bar Layout") {
                Toggle("Hide selected original icons", isOn: Binding(get: { store.layoutManagementEnabled }, set: { store.setLayoutManagementEnabled($0) }))
                Text("Selected icons are Command-dragged to the left of the OverflowBar arrow. They are shown in the second row and temporarily restored when clicked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Apply Hidden Layout") { store.applyLayout() }.disabled(!store.layoutManagementEnabled || store.selectedItems.isEmpty)
                    Button("Restore All Managed Icons") { store.restoreLayout() }.disabled(store.selectedItems.isEmpty)
                    Button("Safe Reset", role: .destructive) { store.restoreAllAndDisable() }.disabled(store.selectedItems.isEmpty)
                }
                if let message = store.layoutOperationMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                HStack {
                    Text("Menu Bar Items")
                    Spacer()
                    Button("Refresh Menu Bar Items") { store.refresh() }
                    Button("Select All") { store.selectAll(true) }.disabled(store.items.isEmpty)
                    Button("Deselect All") { store.selectAll(false) }.disabled(store.items.isEmpty)
                }
                if !permissions.accessibilityGranted { Text("Enable Accessibility to scan and activate menu bar items.").foregroundStyle(.secondary) }
                ForEach(store.items) { item in
                    Toggle(isOn: Binding(get: { item.isSelected }, set: { store.setSelected(item, selected: $0) })) {
                        HStack {
                            icon(for: item)
                            VStack(alignment: .leading) {
                                Text(item.ownerName)
                                Text(item.title).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: item.supportsPressAction ? "hand.tap" : "cursorarrow.click").help(item.supportsPressAction ? "Supports Accessibility press" : "Uses mouse click fallback")
                        }
                    }
                }
                if permissions.accessibilityGranted && store.items.isEmpty { Text("No accessible right-side menu bar items were found. Some apps do not expose status items to Accessibility.").foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 600, minHeight: 420)
        .onAppear { permissions.refresh(); launchAtLogin.refresh(); store.refresh() }
        .alert("OverflowBar", isPresented: Binding(get: { store.lastActivationError != nil }, set: { if !$0 { store.lastActivationError = nil } })) { Button("OK", role: .cancel) { store.lastActivationError = nil } } message: { Text(store.lastActivationError ?? "") }
    }

    @ViewBuilder private func permissionRow(_ name: String, granted: Bool, open: @escaping () -> Void, request: @escaping () -> Void) -> some View {
        HStack {
            Label("\(name): \(granted ? "Granted" : "Not Granted")", systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundStyle(granted ? .green : .orange)
            Spacer()
            if !granted { Button("Open \(name) Settings", action: open); Button("Request", action: request) }
        }
    }

    @ViewBuilder private func icon(for item: MenuBarItem) -> some View {
        if let image = item.iconImage { Image(nsImage: image).resizable().scaledToFit().frame(width: 24, height: 20) }
        else { Image(systemName: "menubar.rectangle").frame(width: 24) }
    }
}

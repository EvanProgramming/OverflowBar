import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: MenuBarItemStore
    var showOnboarding: () -> Void = {}
    var checkForUpdates: () -> Void = {}
    @StateObject private var permissions = PermissionManager()
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @AppStorage("hoverRevealEnabled") private var hoverRevealEnabled = false

    var body: some View {
        Form {
            Section("Updates") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                Button("Check for Updates…", action: checkForUpdates)
                Text("OverflowBar checks periodically and asks before installing updates.").font(.caption).foregroundStyle(.secondary)
            }
            Section("General") {
                Toggle("Open OverflowBar at Login", isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.setEnabled($0) }))
                Toggle("Reveal when the pointer reaches the menu bar", isOn: $hoverRevealEnabled)
                Button("Run Welcome Setup Again", action: showOnboarding)
                Button("Quit OverflowBar", role: .destructive) { NSApp.terminate(nil) }
                if let error = launchAtLogin.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
            }
            Section("Native Icon Group") {
                Text("Select the icons below. OverflowBar uses native drag transactions to arrange them, captures their real previews, and opens their original menus from the second row. Accessibility is required for arrangement and activation.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Arrange Icons") { store.showArrangeInstructions() }
                    Button("Hide Selected Icons") { store.setLayoutManagementEnabled(true) }
                    Button("Open Second Row") { store.onShowPanelRequested?() }
                    Button("Reveal Group") { store.setLayoutManagementEnabled(false) }
                    Button("Safe Reset", role: .destructive) { store.restoreAllAndDisable() }
                }
                if let progress = store.operationProgress { Text(progress); Button("Cancel Operation") { store.cancelOperation() } }
                if let message = store.layoutOperationMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
            }
            Section("Native Engine Permissions") {
                permissionRow("Accessibility", granted: permissions.accessibilityGranted, open: permissions.openAccessibilitySettings, request: permissions.requestAccessibility)
                permissionRow("Screen Recording", granted: permissions.screenRecordingGranted, open: permissions.openScreenRecordingSettings, request: permissions.requestScreenRecording)
                Button("Refresh Permission Status") { permissions.refresh() }
                Text("Accessibility is required to arrange and activate selected native icons. Screen Recording enables genuine previews. If either is denied, OverflowBar shows its limited state explicitly.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Menu Bar Items") {
                HStack {
                    Button("Refresh Items") { store.refresh() }
                    if let message = store.iconCaptureMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                }
                ForEach(store.items) { item in
                    HStack(spacing: 10) {
                        icon(for: item)
                        VStack(alignment: .leading) {
                            Text(item.ownerName)
                            Text(item.tooltip).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("Hide", isOn: Binding(get: { store.selectedIDs.contains(item.id) }, set: { store.setSelected(item, selected: $0) }))
                            .disabled(item.isProtectedSystemItem || item.nativeRecord?.persistentID == nil || store.operationProgress != nil)
                        Image(systemName: item.supportsPressAction ? "hand.tap" : "cursorarrow.click.2")
                            .help(item.supportsPressAction ? "Native Accessibility action available" : "May require a click on the original icon")
                    }
                    .accessibilityElement(children: .combine)
                }
                if store.items.isEmpty { Text("No menu bar items discovered yet.").foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 620, minHeight: 440)
        .onAppear { permissions.refresh(); launchAtLogin.refresh(); store.refresh() }
        .alert("OverflowBar", isPresented: Binding(get: { store.lastActivationError != nil }, set: { if !$0 { store.lastActivationError = nil } })) {
            Button("OK", role: .cancel) { store.lastActivationError = nil }
        } message: { Text(store.lastActivationError ?? "") }
    }

    @ViewBuilder private func permissionRow(_ name: String, granted: Bool, open: @escaping () -> Void, request: @escaping () -> Void) -> some View {
        HStack {
            Label("\(name): \(granted ? "Granted" : "Not Granted")", systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
            Spacer()
            if !granted { Button("Open Settings", action: open); Button("Request", action: request) }
        }
    }

    @ViewBuilder private func icon(for item: MenuBarItem) -> some View {
        if let image = item.displayImage {
            Image(nsImage: image).renderingMode(item.usesTemplateIcon ? .template : .original)
                .resizable().scaledToFit().frame(width: 24, height: 20)
        } else { Image(systemName: item.fallbackSymbolName).frame(width: 24) }
    }
}

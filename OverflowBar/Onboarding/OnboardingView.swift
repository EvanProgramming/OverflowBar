import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: MenuBarItemStore
    @ObservedObject var permissions: PermissionManager
    let onComplete: (Bool) -> Void
    @StateObject private var launchAtLogin = LaunchAtLoginManager()

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tint)
            Text("A quieter menu bar")
                .font(.largeTitle.weight(.semibold))
            Text("Select the icons you want to hide in Settings. OverflowBar arranges them and shows real previews in a second row. Clicking a preview opens the original native menu.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 520)
            VStack(alignment: .leading, spacing: 12) {
                Label("Accessibility is needed to arrange and open native icons", systemImage: "hand.tap")
                Button("Enable Accessibility") { permissions.requestAccessibility() }
                Button("Enable Screen Recording for Real Previews") { permissions.requestScreenRecording() }
                Label("Screen Recording adds icon previews", systemImage: "rectangle.inset.filled")
                Toggle("Open OverflowBar at Login", isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.setEnabled($0) }))
            }
            .frame(maxWidth: 440, alignment: .leading)
            Button("Start Using OverflowBar") {
                onComplete(true)
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            if let error = launchAtLogin.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(36)
        .frame(minWidth: 680, minHeight: 500)
        .task { permissions.refresh(); launchAtLogin.refresh() }
    }
}

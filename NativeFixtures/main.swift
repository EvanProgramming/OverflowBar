import AppKit

final class Fixture: NSObject, NSApplicationDelegate, NSMenuDelegate, NSPopoverDelegate {
    var items: [NSStatusItem] = []
    let popover = NSPopover()
    var window: NSWindow?
    let counters = NSTextField(labelWithString: "Native fixture ready")
    var state: [String: Int] = ["nativeMenus": 0, "popovers": 0, "toggles": 0, "vanished": 0]
    func record(_ key: String) {
        state[key, default: 0] += 1; state["pid"] = Int(getpid())
        counters.stringValue = "Native menus: \(state["nativeMenus"]!)  Popovers: \(state["popovers"]!)  Toggles: \(state["toggles"]!)  Disappeared: \(state["vanished"]!)"
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) { try? data.write(to: URL(fileURLWithPath: "/private/tmp/overflowbar-native-fixture-state.json"), options: .atomic) }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        for (index, label) in ["OB-N", "OB-P", "OB-T", "OB-V"].enumerated() {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.autosaveName = "OverflowBarFixture\(index)"
            item.button?.title = label; item.button?.setAccessibilityIdentifier("fixture.\(index)")
            item.button?.target = self; item.button?.tag = index
            item.button?.action = #selector(clicked(_:))
            if index == 0 {
                let menu = NSMenu(title: "OverflowBar Native Fixture Menu")
                menu.delegate = self
                menu.addItem(withTitle: "Real native menu — fixture", action: nil, keyEquivalent: "")
                let quit = menu.addItem(withTitle: "Quit Fixture", action: #selector(quit), keyEquivalent: "")
                quit.target = self; item.menu = menu
            }
            items.append(item)
        }
        popover.behavior = .transient; popover.delegate = self
        let controller = NSViewController()
        controller.view = NSTextField(labelWithString: "Real native fixture popover")
        controller.view.frame = CGRect(x: 0, y: 0, width: 220, height: 70)
        popover.contentViewController = controller
        let overview = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 540, height: 100), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        overview.title = "OverflowBar Native Fixture"
        counters.frame = CGRect(x: 20, y: 35, width: 500, height: 24)
        overview.contentView?.addSubview(counters); overview.center(); overview.orderFront(nil)
        window = overview
        record("launches")
        if CommandLine.arguments.contains("--unresponsive") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { Thread.sleep(forTimeInterval: 120) }
        }
    }
    func menuWillOpen(_ menu: NSMenu) { record("nativeMenus") }
    func popoverDidShow(_ notification: Notification) { record("popovers") }
    @objc func clicked(_ sender: NSStatusBarButton) {
        switch sender.tag {
        case 1: popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        case 2: record("toggles"); sender.title = "OB-T\(state["toggles"]!)"
        case 3: record("vanished"); NSStatusBar.system.removeStatusItem(items[3])
        default: break
        }
    }
    @objc func quit() { NSApp.terminate(nil) }
}
let app = NSApplication.shared
let delegate = Fixture(); app.delegate = delegate; app.run()

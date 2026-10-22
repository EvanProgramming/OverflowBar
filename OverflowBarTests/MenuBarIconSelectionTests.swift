import XCTest
@testable import OverflowBar

final class MenuBarIconSelectionTests: XCTestCase {
    func testSelectionListOmitsProtectedSystemItems() {
        let systemItems = [
            item(id: "clock", title: "Clock", protected: true),
            item(id: "control-center", title: "Control Center", protected: true)
        ]
        let appItem = item(id: "app", title: "App", protected: false)
        let list = MenuBarIconSelectionList(
            items: [systemItems[0], appItem, systemItems[1]],
            selectedIDs: [],
            allowsSelection: true,
            onRefresh: {},
            onSelectionChange: { _, _ in }
        )

        XCTAssertEqual(list.selectableItems.map(\.id), ["app"])
    }

    private func item(id: String, title: String, protected: Bool) -> MenuBarItem {
        MenuBarItem(
            id: id,
            title: title,
            ownerName: protected ? "Control Center" : "Example App",
            bundleIdentifier: protected ? "com.apple.controlcenter" : "com.example.app",
            frame: .zero,
            axElement: nil,
            supportsPressAction: false,
            isProtectedSystemItem: protected
        )
    }
}

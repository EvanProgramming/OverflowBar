import CoreGraphics

enum MenuBarGroupGeometry {
    static let compactDividerLength: CGFloat = 20

    static func membershipFrame(compactFrame: CGRect?, currentFrame: CGRect?) -> CGRect? {
        compactFrame ?? currentFrame
    }

    static func panelAnchorFrame(buttonFrame: CGRect?, fallbackFrame: CGRect?) -> CGRect? {
        [buttonFrame, fallbackFrame].compactMap { $0 }.first {
            $0.origin.x.isFinite && $0.origin.y.isFinite &&
            $0.width.isFinite && $0.height.isFinite && $0.width > 0 && $0.height > 0
        }
    }

    static func dividerLength(groupHidden: Bool, osMajorVersion: Int, screenWidths: [CGFloat]) -> CGFloat {
        guard groupHidden, supportsHiding(osMajorVersion: osMajorVersion) else { return compactDividerLength }
        return collapsedLength(screenWidths: screenWidths)
    }

    static func compactBoundaryFrame(from frame: CGRect) -> CGRect {
        guard frame.width > compactDividerLength else { return frame }
        return CGRect(x: frame.maxX - compactDividerLength, y: frame.minY, width: compactDividerLength, height: frame.height)
    }

    static func collapsedLength(screenWidths: [CGFloat]) -> CGFloat {
        let widest = screenWidths.filter { $0.isFinite && $0 > 0 }.max() ?? 1_728
        return max(500, min(widest * 2, 10_000))
    }

    static func hiddenItemIDs(itemFrames: [String: CGRect], dividerFrame: CGRect) -> Set<String> {
        Set(itemFrames.compactMap { id, frame in
            frame.width > 0 && frame.maxX <= dividerFrame.minX && frame.maxY > dividerFrame.minY && frame.minY < dividerFrame.maxY ? id : nil
        })
    }

    static func supportsHiding(osMajorVersion: Int) -> Bool {
        (15..<27).contains(osMajorVersion)
    }
}

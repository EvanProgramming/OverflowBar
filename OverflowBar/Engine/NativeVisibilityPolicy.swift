import CoreGraphics

enum NativeVisibilityPolicy {
    static func isUsable(_ frame: CGRect, display: CGRect, segments: [CGRect], accessibilityFrame: CGRect? = nil) -> Bool {
        let content = accessibilityFrame.flatMap { frame.contains($0) ? $0 : nil } ?? frame
        // AppKit safe areas and hosted window bounds can differ by one vertical point.
        return display.contains(frame) && (segments.isEmpty || segments.contains { $0.insetBy(dx: 0, dy: -1).contains(content) })
    }
}

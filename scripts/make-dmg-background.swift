import AppKit

let output = CommandLine.arguments[1]
let size = NSSize(width: 900, height: 560)
let image = NSImage(size: size)
image.lockFocus()

NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()

let accent = NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.82, alpha: 1)
accent.setStroke()
let arrow = NSBezierPath()
arrow.lineWidth = 8
arrow.lineCapStyle = .round
arrow.move(to: NSPoint(x: 330, y: 275))
arrow.line(to: NSPoint(x: 570, y: 275))
arrow.move(to: NSPoint(x: 570, y: 275))
arrow.line(to: NSPoint(x: 525, y: 315))
arrow.move(to: NSPoint(x: 570, y: 275))
arrow.line(to: NSPoint(x: 525, y: 235))
arrow.stroke()

let title = "Install OverflowBar"
let subtitle = "Drag the app to Applications to finish installation"
let titleAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 30, weight: .semibold), .foregroundColor: NSColor.labelColor]
let subtitleAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.secondaryLabelColor]
(title as NSString).draw(at: NSPoint(x: 285, y: 465), withAttributes: titleAttributes)
(subtitle as NSString).draw(at: NSPoint(x: 245, y: 430), withAttributes: subtitleAttributes)

image.unlockFocus()
guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: output))

import AppKit
import Foundation

let output = CommandLine.arguments.dropFirst().first ?? "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let size = 1024
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.current = context
context.imageInterpolation = .high

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}
func rounded(_ rect: CGRect, _ radius: CGFloat, _ fill: NSColor, stroke: NSColor? = nil, width: CGFloat = 1) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = width
        path.stroke()
    }
}
func sparkle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ fill: NSColor) {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: x, y: y + radius))
    path.curve(to: CGPoint(x: x + radius * 0.22, y: y + radius * 0.22),
               controlPoint1: CGPoint(x: x + radius * 0.10, y: y + radius * 0.36),
               controlPoint2: CGPoint(x: x + radius * 0.10, y: y + radius * 0.10))
    path.curve(to: CGPoint(x: x + radius, y: y),
               controlPoint1: CGPoint(x: x + radius * 0.36, y: y + radius * 0.10),
               controlPoint2: CGPoint(x: x + radius * 0.36, y: y + radius * 0.10))
    path.curve(to: CGPoint(x: x + radius * 0.22, y: y - radius * 0.22),
               controlPoint1: CGPoint(x: x + radius * 0.36, y: y - radius * 0.10),
               controlPoint2: CGPoint(x: x + radius * 0.10, y: y - radius * 0.10))
    path.curve(to: CGPoint(x: x, y: y - radius),
               controlPoint1: CGPoint(x: x + radius * 0.10, y: y - radius * 0.36),
               controlPoint2: CGPoint(x: x + radius * 0.10, y: y - radius * 0.36))
    path.curve(to: CGPoint(x: x - radius * 0.22, y: y - radius * 0.22),
               controlPoint1: CGPoint(x: x - radius * 0.10, y: y - radius * 0.36),
               controlPoint2: CGPoint(x: x - radius * 0.10, y: y - radius * 0.10))
    path.curve(to: CGPoint(x: x - radius, y: y),
               controlPoint1: CGPoint(x: x - radius * 0.36, y: y - radius * 0.10),
               controlPoint2: CGPoint(x: x - radius * 0.36, y: y - radius * 0.10))
    path.curve(to: CGPoint(x: x - radius * 0.22, y: y + radius * 0.22),
               controlPoint1: CGPoint(x: x - radius * 0.36, y: y + radius * 0.10),
               controlPoint2: CGPoint(x: x - radius * 0.10, y: y + radius * 0.10))
    path.close()
    fill.setFill()
    path.fill()
}

let bounds = CGRect(x: 0, y: 0, width: size, height: size)
let background = NSGradient(colors: [
    color(0.36, 0.55, 0.96), color(0.68, 0.48, 0.94), color(1.0, 0.63, 0.78)
])!
background.draw(in: bounds, angle: -35)

// Soft pastel glows and floating stars.
color(1.0, 0.80, 0.63, 0.35).setFill()
NSBezierPath(ovalIn: CGRect(x: 730, y: 690, width: 260, height: 260)).fill()
color(0.62, 0.82, 1.0, 0.30).setFill()
NSBezierPath(ovalIn: CGRect(x: -90, y: 80, width: 300, height: 300)).fill()
sparkle(835, 840, 64, color(1.0, 0.91, 0.55))
sparkle(180, 770, 28, color(1.0, 0.92, 0.69))
sparkle(890, 555, 22, color(1.0, 0.94, 0.77))
sparkle(120, 430, 15, color(1.0, 0.92, 0.72))

// Folder tabs peeking out of the happy archive box.
rounded(CGRect(x: 230, y: 490, width: 570, height: 270), 62, color(0.99, 0.76, 0.28))
rounded(CGRect(x: 300, y: 475, width: 480, height: 300), 58, color(0.35, 0.72, 0.98))
rounded(CGRect(x: 385, y: 500, width: 390, height: 265), 55, color(1.0, 0.91, 0.76))

// Main lavender container.
let boxGradient = NSGradient(colors: [color(0.76, 0.59, 1.0), color(0.53, 0.36, 0.88), color(0.43, 0.29, 0.78)])!
boxGradient.draw(in: NSBezierPath(roundedRect: CGRect(x: 120, y: 125, width: 784, height: 500), xRadius: 100, yRadius: 100), angle: -90)
rounded(CGRect(x: 120, y: 515, width: 784, height: 125), 48, color(0.75, 0.60, 1.0), stroke: color(0.88, 0.79, 1.0, 0.8), width: 5)
rounded(CGRect(x: 450, y: 480, width: 124, height: 105), 30, color(0.94, 0.87, 1.0), stroke: color(1, 1, 1, 0.7), width: 4)

// Friendly face.
color(0.20, 0.13, 0.31).setFill()
NSBezierPath(ovalIn: CGRect(x: 330, y: 285, width: 82, height: 112)).fill()
NSBezierPath(ovalIn: CGRect(x: 612, y: 285, width: 82, height: 112)).fill()
color(1, 1, 1).setFill()
NSBezierPath(ovalIn: CGRect(x: 350, y: 360, width: 22, height: 22)).fill()
NSBezierPath(ovalIn: CGRect(x: 632, y: 360, width: 22, height: 22)).fill()
color(1.0, 0.48, 0.65, 0.95).setFill()
NSBezierPath(ovalIn: CGRect(x: 260, y: 260, width: 90, height: 42)).fill()
NSBezierPath(ovalIn: CGRect(x: 675, y: 260, width: 90, height: 42)).fill()
let smile = NSBezierPath()
smile.move(to: CGPoint(x: 455, y: 310))
smile.curve(to: CGPoint(x: 570, y: 310), controlPoint1: CGPoint(x: 465, y: 225), controlPoint2: CGPoint(x: 560, y: 225))
smile.curve(to: CGPoint(x: 455, y: 310), controlPoint1: CGPoint(x: 560, y: 260), controlPoint2: CGPoint(x: 465, y: 260))
color(0.22, 0.12, 0.34).setFill()
smile.fill()
let tongue = NSBezierPath(ovalIn: CGRect(x: 480, y: 248, width: 65, height: 32))
color(1.0, 0.32, 0.55).setFill()
tongue.fill()

// Tiny green success sticker on the upper corner.
rounded(CGRect(x: 690, y: 640, width: 150, height: 132), 42, color(0.34, 0.83, 0.55), stroke: color(0.76, 1.0, 0.83), width: 5)
let check = NSBezierPath()
check.move(to: CGPoint(x: 730, y: 705))
check.line(to: CGPoint(x: 765, y: 670))
check.line(to: CGPoint(x: 810, y: 725))
check.lineWidth = 17
check.lineCapStyle = .round
check.lineJoinStyle = .round
color(1, 1, 1).setStroke()
check.stroke()

NSGraphicsContext.restoreGraphicsState()
let png = bitmap.representation(using: .png, properties: [:])!
let url = URL(fileURLWithPath: output)
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: url)
print("Generated TangiExtract app icon at \(url.path)")

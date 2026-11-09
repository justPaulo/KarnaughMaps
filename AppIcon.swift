import AppKit

private let canvasSize: CGFloat = 1024

private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

private func drawIcon() -> NSImage {
    let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
    image.lockFocusFlipped(true)
    defer { image.unlockFocus() }

    let background = NSBezierPath(roundedRect: NSRect(x: 38, y: 38, width: 948, height: 948), xRadius: 220, yRadius: 220)
    NSGradient(colors: [
        color(0.10, 0.13, 0.37),
        color(0.17, 0.23, 0.59),
        color(0.12, 0.44, 0.68)
    ])?.draw(in: background, angle: 45)

    let glow = NSBezierPath(ovalIn: NSRect(x: 510, y: 70, width: 430, height: 430))
    color(0.30, 0.89, 0.97, 0.12).setFill()
    glow.fill()

    drawWire(from: NSPoint(x: 90, y: 360), to: NSPoint(x: 272, y: 360), color: color(0.40, 0.93, 1))
    drawWire(from: NSPoint(x: 90, y: 660), to: NSPoint(x: 272, y: 660), color: color(0.40, 0.93, 1))
    drawWire(from: NSPoint(x: 694, y: 510), to: NSPoint(x: 916, y: 510), color: color(1.0, 0.56, 0.81))
    drawTerminal(at: NSPoint(x: 90, y: 360), fill: color(0.48, 0.96, 1))
    drawTerminal(at: NSPoint(x: 90, y: 660), fill: color(0.48, 0.96, 1))
    drawTerminal(at: NSPoint(x: 916, y: 510), fill: color(1.0, 0.67, 0.85))

    let shadow = NSShadow()
    shadow.shadowColor = color(0.035, 0.05, 0.20, 0.58)
    shadow.shadowBlurRadius = 34
    shadow.shadowOffset = NSSize(width: 0, height: 20)
    shadow.set()

    let gate = NSBezierPath()
    gate.move(to: NSPoint(x: 260, y: 260))
    gate.line(to: NSPoint(x: 500, y: 260))
    gate.curve(to: NSPoint(x: 500, y: 760), controlPoint1: NSPoint(x: 830, y: 260), controlPoint2: NSPoint(x: 830, y: 760))
    gate.line(to: NSPoint(x: 260, y: 760))
    gate.close()
    NSGradient(colors: [
        color(0.53, 0.92, 1.0),
        color(0.22, 0.70, 0.94),
        color(0.20, 0.43, 0.86)
    ])?.draw(in: gate, angle: 90)
    NSShadow().set()

    let gateOutline = NSBezierPath()
    gateOutline.move(to: NSPoint(x: 260, y: 260))
    gateOutline.line(to: NSPoint(x: 500, y: 260))
    gateOutline.curve(to: NSPoint(x: 500, y: 760), controlPoint1: NSPoint(x: 830, y: 260), controlPoint2: NSPoint(x: 830, y: 760))
    gateOutline.line(to: NSPoint(x: 260, y: 760))
    gateOutline.close()
    color(0.80, 0.98, 1.0, 0.82).setStroke()
    gateOutline.lineWidth = 9
    gateOutline.stroke()

    let gloss = NSBezierPath(roundedRect: NSRect(x: 282, y: 280, width: 215, height: 26), xRadius: 13, yRadius: 13)
    color(1, 1, 1, 0.42).setFill()
    gloss.fill()

    let label = NSAttributedString(
        string: "AND",
        attributes: [
            .font: NSFont.systemFont(ofSize: 44, weight: .heavy),
            .foregroundColor: color(0.91, 0.98, 1.0, 0.94),
            .kern: 8
        ]
    )
    label.draw(at: NSPoint(x: 410, y: 650))

    let outputBubble = NSBezierPath(ovalIn: NSRect(x: 674, y: 490, width: 40, height: 40))
    color(1.0, 0.79, 0.90).setFill()
    outputBubble.fill()
    color(1, 1, 1, 0.95).setStroke()
    outputBubble.lineWidth = 6
    outputBubble.stroke()

    return image
}

private func drawWire(from start: NSPoint, to end: NSPoint, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    path.lineWidth = 18
    path.lineCapStyle = .round
    color.setStroke()
    path.stroke()

    let shine = NSBezierPath()
    shine.move(to: NSPoint(x: start.x, y: start.y - 5))
    shine.line(to: NSPoint(x: end.x, y: end.y - 5))
    shine.lineWidth = 4
    shine.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.45).setStroke()
    shine.stroke()
}

private func drawTerminal(at point: NSPoint, fill: NSColor) {
    let terminal = NSBezierPath(ovalIn: NSRect(x: point.x - 19, y: point.y - 19, width: 38, height: 38))
    fill.setFill()
    terminal.fill()
    NSColor.white.withAlphaComponent(0.85).setStroke()
    terminal.lineWidth = 5
    terminal.stroke()
}

private func pngData(from image: NSImage, pixelSize: Int) -> Data? {
    let size = NSSize(width: pixelSize, height: pixelSize)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current = context
    context?.imageInterpolation = .high
    image.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
}

@main
private struct AppIconGenerator {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            fatalError("Usage: AppIcon <iconset-directory>")
        }

        let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

        let image = drawIcon()
        let representations: [(name: String, pixels: Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024)
        ]

        for representation in representations {
            guard let data = pngData(from: image, pixelSize: representation.pixels) else {
                fatalError("Could not encode \(representation.name)")
            }
            try data.write(to: iconsetURL.appendingPathComponent(representation.name))
        }
    }
}

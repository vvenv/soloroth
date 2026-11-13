#!/usr/bin/swift
// Draws tools/macos/AppIcon.png (1024×1024). make-app.sh turns it into the
// Soloroth.app icon. The mark is original: a gold sword in a ring, on a night
// field. macOS applies the squircle mask, so this image stays square and opaque.
import AppKit

let size = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

guard let rep = NSBitmapImageRep(
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
) else {
    fputs("could not allocate the icon bitmap\n", stderr)
    exit(1)
}
rep.size = NSSize(width: size, height: size)

func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let canvas = NSRect(x: 0, y: 0, width: size, height: size)
srgb(0.04, 0.05, 0.09).setFill()
canvas.fill()

let glow = NSGradient(colorsAndLocations: (
    srgb(0.20, 0.31, 0.50), 0
), (
    srgb(0.09, 0.13, 0.23), 0.52
), (
    srgb(0.04, 0.05, 0.09), 1
))!
let glowCenter = NSPoint(x: 512, y: 560)
glow.draw(fromCenter: glowCenter, radius: 0, toCenter: glowCenter, radius: 760, options: [])

let disc = NSBezierPath(ovalIn: canvas.insetBy(dx: 168, dy: 168))
NSGradient(colors: [srgb(0.14, 0.19, 0.32), srgb(0.07, 0.10, 0.17)])?
    .draw(in: disc, angle: -90)

let goldLight = srgb(0.99, 0.91, 0.66)
let gold = srgb(0.93, 0.76, 0.40)
let goldDeep = srgb(0.62, 0.44, 0.16)

let blade = NSBezierPath()
blade.move(to: NSPoint(x: 512, y: 748))
blade.line(to: NSPoint(x: 562, y: 392))
blade.line(to: NSPoint(x: 462, y: 392))
blade.close()
NSGradient(colors: [goldLight, gold, goldDeep])?.draw(in: blade, angle: -90)

// A narrow fuller, so the blade reads as a sword and not a wedge.
let fuller = NSBezierPath()
fuller.move(to: NSPoint(x: 512, y: 700))
fuller.line(to: NSPoint(x: 522, y: 420))
fuller.line(to: NSPoint(x: 502, y: 420))
fuller.close()
srgb(0.55, 0.40, 0.16, 0.55).setFill()
fuller.fill()

let guardRect = NSRect(x: 392, y: 360, width: 240, height: 52)
let crossguard = NSBezierPath(roundedRect: guardRect, xRadius: 12, yRadius: 12)
NSGradient(colors: [goldLight, goldDeep])?.draw(in: crossguard, angle: -90)

let gripRect = NSRect(x: 490, y: 236, width: 44, height: 132)
let grip = NSBezierPath(roundedRect: gripRect, xRadius: 10, yRadius: 10)
srgb(0.45, 0.30, 0.12).setFill()
grip.fill()
// Two bands on the grip, visible at large sizes only.
for y in [268, 312] as [CGFloat] {
    let band = NSBezierPath(rect: NSRect(x: 490, y: y, width: 44, height: 10))
    gold.setFill()
    band.fill()
}

let pommel = NSBezierPath(ovalIn: NSRect(x: 478, y: 186, width: 68, height: 68))
NSGradient(colors: [goldLight, goldDeep])?.draw(in: pommel, angle: -90)
let pommelHole = NSBezierPath(ovalIn: NSRect(x: 498, y: 206, width: 28, height: 28))
srgb(0.10, 0.13, 0.20).setFill()
pommelHole.fill()

let ring = NSBezierPath(ovalIn: canvas.insetBy(dx: 132, dy: 132))
gold.setStroke()
ring.lineWidth = 28
ring.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("could not encode the icon\n", stderr)
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: out))
} catch {
    fputs("could not write \(out): \(error)\n", stderr)
    exit(1)
}

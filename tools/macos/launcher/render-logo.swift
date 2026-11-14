#!/usr/bin/swift
// Draws tools/macos/launcher/logo.png, the launcher's wordmark: SOLOROTH in
// Hoefler Text Black with its first O swapped for the icon's ring and sword
// (render-icon.swift). Transparent, at 3x, with even padding for the shadow so
// its center is the wordmark's center. launcher.json places and sizes it.
//
//   swift tools/macos/launcher/render-logo.swift [out.png]
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "logo.png"
let scale: CGFloat = 3
let pad: CGFloat = 20

func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
let goldLight = srgb(0.99, 0.91, 0.66)
let gold = srgb(0.93, 0.76, 0.40)
let goldDeep = srgb(0.62, 0.44, 0.16)
let ink = srgb(0.17, 0.10, 0.03)

guard let font = NSFont(name: "HoeflerText-Black", size: 66) else {
    fputs("render-logo: Hoefler Text Black is missing\n", stderr)
    exit(1)
}
let cap = font.capHeight
let ringSide = cap * 1.06, stem = cap * 0.17, gap = cap * 0.12

func glyphs(_ s: String) -> (CGPath, CGFloat) {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: font]))
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let n = CTRunGetGlyphCount(run)
        var ids = [CGGlyph](repeating: 0, count: n)
        var at = [CGPoint](repeating: .zero, count: n)
        CTRunGetGlyphs(run, CFRange(location: 0, length: n), &ids)
        CTRunGetPositions(run, CFRange(location: 0, length: n), &at)
        for i in 0..<n {
            guard let g = CTFontCreatePathForGlyph(font, ids[i], nil) else { continue }
            path.addPath(g, transform: CGAffineTransform(translationX: at[i].x, y: at[i].y))
        }
    }
    return (path, CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)))
}

let (s, sWidth) = glyphs("S"), (rest, restWidth) = glyphs("LOROTH")
// The blade rises 1.42 caps over the baseline and the pommel hangs 0.46 under it.
let above = cap * 1.42, below = cap * 0.46
let size = NSSize(width: sWidth + gap + ringSide + gap + restWidth + pad * 2, height: above + below + pad * 2)
let baseline = pad + below

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(ceil(size.width * scale)),
                                 pixelsHigh: Int(ceil(size.height * scale)), bitsPerSample: 8,
                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let ctx = NSGraphicsContext(bitmapImageRep: rep) else { exit(1) }
NSGraphicsContext.current = ctx
let cg = ctx.cgContext
cg.scaleBy(x: scale, y: scale)

// A dark outline and a drop shadow so the gold holds on bright cloud, then the
// icon's gold top to bottom. CG shadows ignore the CTM, hence the scale.
func engrave(_ path: CGPath, from bottom: CGFloat, to top: CGFloat, colors: [NSColor] = [goldDeep, gold, goldLight]) {
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -3 * scale), blur: 10 * scale, color: srgb(0, 0, 0, 0.75).cgColor)
    cg.addPath(path)
    cg.setFillColor(ink.cgColor)
    cg.fillPath()
    cg.restoreGState()

    cg.saveGState()
    cg.addPath(path)
    cg.setLineWidth(3)
    cg.setLineJoin(.round)
    cg.setStrokeColor(ink.cgColor)
    cg.strokePath()
    cg.addPath(path)
    cg.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: colors.map(\.cgColor) as CFArray, locations: nil)!
    cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: bottom), end: CGPoint(x: 0, y: top), options: [])
    cg.restoreGState()
}

let ringX = pad + sWidth + gap
let x = ringX + ringSide / 2
let letters = CGMutablePath()
letters.addPath(s, transform: CGAffineTransform(translationX: pad, y: baseline))
letters.addPath(rest, transform: CGAffineTransform(translationX: ringX + ringSide + gap, y: baseline))
let ringCenterY = baseline + cap / 2
let ring = CGPath(ellipseIn: CGRect(x: x - ringSide / 2 + stem / 2, y: ringCenterY - ringSide / 2 + stem / 2,
                                    width: ringSide - stem, height: ringSide - stem), transform: nil)
    .copy(strokingWithWidth: stem, lineCap: .butt, lineJoin: .miter, miterLimit: 4)
engrave(letters, from: baseline, to: baseline + cap)
engrave(ring, from: baseline, to: baseline + cap)

// The sword stands in front of the ring; the crossguard sits above the ring's
// bottom so the ring still shows under it.
let tip = baseline + above, guardY = baseline + cap * 0.22
let bladeHalf = cap * 0.12, guardHalf = cap * 0.40, guardH = cap * 0.13

let blade = CGMutablePath()
blade.move(to: CGPoint(x: x, y: tip))
blade.addLine(to: CGPoint(x: x + bladeHalf, y: guardY + guardH))
blade.addLine(to: CGPoint(x: x - bladeHalf, y: guardY + guardH))
blade.closeSubpath()
engrave(blade, from: guardY, to: tip)
let ridge = CGMutablePath()
ridge.move(to: CGPoint(x: x, y: tip - cap * 0.18))
ridge.addLine(to: CGPoint(x: x + bladeHalf * 0.22, y: guardY + guardH))
ridge.addLine(to: CGPoint(x: x - bladeHalf * 0.22, y: guardY + guardH))
ridge.closeSubpath()
cg.addPath(ridge)
cg.setFillColor(goldDeep.withAlphaComponent(0.6).cgColor)
cg.fillPath()

let gripW = cap * 0.13, gripBottom = baseline - cap * 0.30
let grip = CGPath(roundedRect: CGRect(x: x - gripW / 2, y: gripBottom, width: gripW, height: guardY - gripBottom),
                  cornerWidth: gripW * 0.3, cornerHeight: gripW * 0.3, transform: nil)
engrave(grip, from: gripBottom, to: guardY, colors: [srgb(0.33, 0.21, 0.08), srgb(0.47, 0.31, 0.13)])
let pommelR = cap * 0.11
let pommel = CGPath(ellipseIn: CGRect(x: x - pommelR, y: gripBottom - pommelR * 1.4,
                                      width: pommelR * 2, height: pommelR * 2), transform: nil)
engrave(pommel, from: gripBottom - pommelR * 1.4, to: gripBottom + pommelR * 0.6)
let crossguard = CGPath(roundedRect: CGRect(x: x - guardHalf, y: guardY, width: guardHalf * 2, height: guardH),
                        cornerWidth: guardH * 0.35, cornerHeight: guardH * 0.35, transform: nil)
engrave(crossguard, from: guardY, to: guardY + guardH)

NSGraphicsContext.current = nil
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
do {
    try png.write(to: URL(fileURLWithPath: out))
} catch {
    fputs("render-logo: could not write \(out): \(error)\n", stderr)
    exit(1)
}
print("\(out): \(rep.pixelsWide)x\(rep.pixelsHigh) (\(Int(size.width))x\(Int(size.height)) pt)")

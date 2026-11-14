// Soloroth.app's launcher window. It starts the server (play.sh --no-client)
// as soon as it opens, shows the art and an optional promo, and exits when
// the player is done with it; the app's launch script then runs the client
// and brings this window back when the game quits.
//
//   Launcher --root <checkout>                         the window
//   Launcher --root <checkout> --snapshot out.png      render it to a PNG and exit
//            [--config extra.json]                     with extra keys on top
//            [--hero N]                                show heroes[N], not a random one
//
// Exit codes: 0 play (the server is up), 1 the player closed the window,
// 2 skipped ("skip": true in the config), 64 bad arguments. The launch script
// starts the game without the window on any code but 0, 1 and a signal, and
// only loops back here after a 0.
//
// Content comes from tools/macos/launcher/launcher.json; benilla-config/launcher.json
// replaces any of its top-level keys. The promo shows only when it has a title or text.
// Each opening picks one of "heroes" (a snapshot takes the first): its image is the
// background art (filled, right edge kept), and its "logo" and "slogan" say where
// the centers of those go, in window points from the top left. Without heroes the
// window draws the icon's sword and ring on a night field.
import AppKit

struct Link: Codable { var title: String?; var url: String? }
struct Promo: Codable { var title: String?; var text: String?; var url: String?; var image: String? }
struct Place: Codable { var x: CGFloat?; var y: CGFloat? }
struct Hero: Codable { var image: String?; var logo: Place?; var slogan: Place? }
struct LogoStyle: Codable { var image: String?; var width: CGFloat? }
struct SloganStyle: Codable { var text: String?; var size: CGFloat?; var rule: CGFloat? }
struct Config: Codable {
    var skip: Bool?
    var heroes: [Hero]?
    var logo: LogoStyle?
    var slogan: SloganStyle?
    var links: [Link]?
    var promo: Promo?
}

func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

// The icon's palette (render-icon.swift).
let night = srgb(0.04, 0.05, 0.09)
let glowBlue = srgb(0.20, 0.31, 0.50)
let goldLight = srgb(0.99, 0.91, 0.66)
let gold = srgb(0.93, 0.76, 0.40)
let goldDeep = srgb(0.62, 0.44, 0.16)
let cream = srgb(0.92, 0.88, 0.80)
let muted = srgb(0.62, 0.62, 0.66)

let windowSize = NSSize(width: 960, height: 600)
let margin: CGFloat = 56
let barHeight: CGFloat = 84

// MARK: - Arguments and config

var root = FileManager.default.currentDirectoryPath
var snapshotPath: String?
var extraConfigs: [String] = []
var heroIndex: Int?
do {
    var args = CommandLine.arguments.dropFirst().makeIterator()
    while let a = args.next() {
        switch a {
        case "--root": root = args.next() ?? root
        case "--snapshot": snapshotPath = args.next()
        case "--config": if let p = args.next() { extraConfigs.append(p) }
        case "--hero":
            guard let n = args.next().flatMap({ Int($0) }) else { fallthrough }
            heroIndex = n
        default:
            fputs("usage: Launcher --root <checkout> [--snapshot out.png] [--config extra.json] [--hero N]\n",
                  stderr)
            exit(64)
        }
    }
    if snapshotPath != nil, heroIndex == nil { heroIndex = 0 }
}

func jsonObject(_ path: String) -> [String: Any] {
    guard let data = FileManager.default.contents(atPath: path) else { return [:] }
    guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
        fputs("launcher: \(path) is not a JSON object, ignored\n", stderr)
        return [:]
    }
    return object
}

func loadConfig() -> Config {
    var merged = jsonObject("\(root)/tools/macos/launcher/launcher.json")
    for path in ["\(root)/benilla-config/launcher.json"] + extraConfigs {
        merged.merge(jsonObject(path)) { _, new in new }
    }
    guard let data = try? JSONSerialization.data(withJSONObject: merged),
          let config = try? JSONDecoder().decode(Config.self, from: data) else {
        fputs("launcher: the config does not decode, using defaults\n", stderr)
        return Config()
    }
    return config
}

func nonEmpty(_ s: String?) -> String? {
    guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
    return s
}

func openURL(_ s: String?) {
    if let s = nonEmpty(s), let url = URL(string: s) { NSWorkspace.shared.open(url) }
}

// MARK: - Views

class Flipped: NSView {
    override var isFlipped: Bool { true }
}

// The hero art, filling the window with its right edge kept (the art's subject
// stands there); without one, a night field with the icon's sword and ring.
final class Backdrop: NSView {
    var hero: NSImage?

    override func draw(_ dirty: NSRect) {
        let b = bounds
        night.setFill()
        b.fill()

        if let hero, hero.size.width > 0, hero.size.height > 0 {
            let scale = max(b.width / hero.size.width, b.height / hero.size.height)
            let size = NSSize(width: hero.size.width * scale, height: hero.size.height * scale)
            hero.draw(in: NSRect(x: b.width - size.width, y: (b.height - size.height) / 2,
                                 width: size.width, height: size.height),
                      from: .zero, operation: .sourceOver, fraction: 1)
            shade(b)
            return
        }

        let center = NSPoint(x: b.width * 0.70, y: b.height * 0.52)
        NSGradient(colorsAndLocations: (glowBlue, 0), (srgb(0.09, 0.13, 0.23), 0.5), (night, 1))!
            .draw(fromCenter: center, radius: 0, toCenter: center, radius: 640, options: [])

        // Stars from a fixed seed, so every launch and snapshot draws the same sky.
        var seed: UInt32 = 1873
        func next() -> CGFloat {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return CGFloat(seed >> 8) / CGFloat(1 << 24)
        }
        for _ in 0..<140 {
            let p = NSPoint(x: next() * b.width, y: b.height * 0.25 + next() * b.height * 0.75)
            let r = 0.4 + next() * 1.1
            srgb(1, 1, 1, 0.15 + next() * 0.5).setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)).fill()
        }

        if let cg = NSGraphicsContext.current?.cgContext {
            cg.saveGState()
            cg.setAlpha(0.22)
            cg.translateBy(x: center.x, y: center.y)
            cg.scaleBy(x: 0.62, y: 0.62)
            cg.translateBy(x: -512, y: -512)
            drawEmblem()
            cg.restoreGState()
        }

        shade(b)
    }

    // Darken the bottom for the bar and the promo, and the top edge.
    private func shade(_ b: NSRect) {
        NSGradient(colors: [srgb(0, 0, 0, 0.75), srgb(0, 0, 0, 0)])!
            .draw(in: NSRect(x: 0, y: 0, width: b.width, height: b.height * 0.4), angle: 90)
        NSGradient(colors: [srgb(0, 0, 0, 0.45), srgb(0, 0, 0, 0)])!
            .draw(in: NSRect(x: 0, y: b.height - 60, width: b.width, height: 60), angle: -90)
    }

    // render-icon.swift's mark in its 1024-unit space, without the disc.
    private func drawEmblem() {
        let blade = NSBezierPath()
        blade.move(to: NSPoint(x: 512, y: 748))
        blade.line(to: NSPoint(x: 562, y: 392))
        blade.line(to: NSPoint(x: 462, y: 392))
        blade.close()
        NSGradient(colors: [goldLight, gold, goldDeep])?.draw(in: blade, angle: -90)
        let crossguard = NSBezierPath(roundedRect: NSRect(x: 392, y: 360, width: 240, height: 52),
                                      xRadius: 12, yRadius: 12)
        NSGradient(colors: [goldLight, goldDeep])?.draw(in: crossguard, angle: -90)
        srgb(0.45, 0.30, 0.12).setFill()
        NSBezierPath(roundedRect: NSRect(x: 490, y: 236, width: 44, height: 132), xRadius: 10, yRadius: 10).fill()
        NSGradient(colors: [goldLight, goldDeep])?
            .draw(in: NSBezierPath(ovalIn: NSRect(x: 478, y: 186, width: 68, height: 68)), angle: -90)
        let ring = NSBezierPath(ovalIn: NSRect(x: 132, y: 132, width: 760, height: 760))
        gold.setStroke()
        ring.lineWidth = 28
        ring.stroke()
    }
}

final class Panel: Flipped {
    var fill = srgb(0, 0, 0, 0.55)
    var border = srgb(0.93, 0.76, 0.40, 0.28)
    var onClick: (() -> Void)?

    override func draw(_ dirty: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        fill.setFill()
        path.fill()
        border.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override func resetCursorRects() {
        if onClick != nil { addCursorRect(bounds, cursor: .pointingHand) }
    }

    override func mouseUp(with event: NSEvent) { onClick?() }
}

final class Bar: NSView {
    override func draw(_ dirty: NSRect) {
        NSGradient(colors: [srgb(0.01, 0.02, 0.04, 0.88), srgb(0.03, 0.04, 0.08, 0.7)])!.draw(in: bounds, angle: 90)
        NSGradient(colorsAndLocations: (srgb(0.93, 0.76, 0.40, 0), 0), (srgb(0.93, 0.76, 0.40, 0.45), 0.5),
                   (srgb(0.93, 0.76, 0.40, 0), 1))!
            .draw(in: NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1), angle: 0)
    }
}

// Raised: lit from above, standing on a darker lip that it sinks onto when
// pressed. NSButton is flipped, so gradient angle 90 runs top to bottom. Drawn
// inset so its glow and shadow stay inside the frame.
final class PlayButton: NSButton {
    static let glowInset: CGFloat = 8
    static let lip: CGFloat = 3

    override func draw(_ dirty: NSRect) {
        let frame = bounds.insetBy(dx: Self.glowInset, dy: Self.glowInset)
        let pressed = isEnabled && isHighlighted
        let drop = pressed ? Self.lip - 1 : 0
        var face = frame
        face.size.height -= Self.lip
        face.origin.y += drop
        let base = NSBezierPath(roundedRect: frame, xRadius: 7, yRadius: 7)
        let top = NSBezierPath(roundedRect: face, xRadius: 7, yRadius: 7)

        if isEnabled {
            NSGraphicsContext.saveGraphicsState()
            let glow = NSShadow()
            glow.shadowColor = srgb(0.99, 0.80, 0.35, pressed ? 0.22 : 0.4)
            glow.shadowBlurRadius = 12
            glow.set()
            srgb(0.36, 0.23, 0.07).setFill()
            base.fill()
            NSGraphicsContext.restoreGraphicsState()

            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = srgb(0, 0, 0, pressed ? 0.35 : 0.6)
            shadow.shadowOffset = NSSize(width: 0, height: pressed ? -1 : -3)
            shadow.shadowBlurRadius = pressed ? 2 : 5
            shadow.set()
            srgb(0.36, 0.23, 0.07).setFill()
            base.fill()
            NSGraphicsContext.restoreGraphicsState()

            let light = pressed ? gold : goldLight
            NSGradient(colorsAndLocations: (light, 0), (gold, 0.5), (srgb(0.80, 0.60, 0.26), 1))?
                .draw(in: top, angle: 90)
            NSGraphicsContext.saveGraphicsState()
            top.addClip()
            srgb(1, 0.97, 0.85, pressed ? 0.3 : 0.75).setFill()
            NSRect(x: face.minX + 6, y: face.minY + 1, width: face.width - 12, height: 1).fill()
            NSGraphicsContext.restoreGraphicsState()
            srgb(0.30, 0.19, 0.05, 0.8).setStroke()
            let rim = NSBezierPath(roundedRect: face.insetBy(dx: 0.5, dy: 0.5), xRadius: 6.5, yRadius: 6.5)
            rim.lineWidth = 1
            rim.stroke()
        } else {
            srgb(0.15, 0.15, 0.17).setFill()
            base.fill()
            srgb(0.25, 0.25, 0.28).setFill()
            top.fill()
        }

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        var attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 17, weight: .bold),
            .foregroundColor: isEnabled ? srgb(0.20, 0.12, 0.03) : muted,
            .paragraphStyle: style,
        ]
        if isEnabled {
            let emboss = NSShadow()
            emboss.shadowColor = srgb(1, 0.95, 0.80, 0.5)
            emboss.shadowOffset = NSSize(width: 0, height: -1)
            attrs[.shadow] = emboss
        }
        let text = NSAttributedString(string: title, attributes: attrs)
        let h = text.size().height
        text.draw(in: NSRect(x: 0, y: face.midY - h / 2, width: bounds.width, height: h))
    }
}

// The slogan: letter-spaced text between two gold rules that fade outward.
final class Slogan: Flipped {
    static let ruleGap: CGFloat = 16
    let text: NSAttributedString
    let rule: CGFloat

    init(_ string: String, size: CGFloat, rule: CGFloat) {
        let kern = (size * 0.4).rounded()
        let shadow = NSShadow()
        shadow.shadowColor = srgb(0, 0, 0, 0.8)
        shadow.shadowBlurRadius = 4
        text = NSAttributedString(string: string, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .medium),
            .foregroundColor: srgb(0.95, 0.91, 0.82, 0.92),
            .kern: kern,
            .shadow: shadow,
        ])
        self.rule = rule
        let t = text.size()
        let side = rule > 0 ? rule + Self.ruleGap : 0
        super.init(frame: NSRect(x: 0, y: 0, width: ceil(t.width + side * 2), height: ceil(t.height) + 8))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirty: NSRect) {
        let t = text.size()
        let side = rule > 0 ? rule + Self.ruleGap : 0
        // Core Text kerns after the last glyph too; leave that out of the centering.
        let kern = text.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat ?? 0
        text.draw(at: NSPoint(x: side + kern / 2, y: (bounds.height - t.height) / 2))
        guard rule > 0 else { return }
        let fade = srgb(0.93, 0.76, 0.40, 0), line = srgb(0.93, 0.76, 0.40, 0.8)
        let y = (bounds.height / 2).rounded()
        NSGradient(colors: [fade, line])!.draw(in: NSRect(x: 0, y: y, width: rule, height: 1), angle: 0)
        NSGradient(colors: [line, fade])!
            .draw(in: NSRect(x: bounds.width - rule, y: y, width: rule, height: 1), angle: 0)
    }
}

func label(_ text: String, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular,
           width: CGFloat) -> NSTextField {
    let field = NSTextField(wrappingLabelWithString: text)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = color
    field.isSelectable = false
    field.preferredMaxLayoutWidth = width
    let height = field.cell!.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: 10_000)).height
    field.frame = NSRect(x: 0, y: 0, width: width, height: ceil(height))
    return field
}

func linkButton(_ title: String, target: AnyObject, action: Selector) -> NSButton {
    let button = NSButton(title: title, target: target, action: action)
    button.isBordered = false
    button.attributedTitle = NSAttributedString(string: title, attributes: [
        .font: NSFont.systemFont(ofSize: 13), .foregroundColor: cream,
    ])
    button.sizeToFit()
    return button
}

// MARK: - The window

enum ServerState {
    case starting, ready, stopping, stopped
    case failed(Int32)
}

final class Launcher: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let config = loadConfig()
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: windowSize),
                          styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
    let content = Flipped(frame: NSRect(origin: .zero, size: windowSize))
    let status = NSTextField(labelWithString: "")
    let detail = NSTextField(labelWithString: "")
    let play = PlayButton(title: "开始游戏", target: nil, action: nil)
    var state = ServerState.stopped
    var wantsPlay = false
    var links: [String] = []

    func build() {
        window.title = "Soloroth"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = night
        window.delegate = self
        window.contentView = content

        let heroes = config.heroes ?? []
        let hero = heroes.isEmpty ? Hero()
            : heroes[heroIndex.map { min(max($0, 0), heroes.count - 1) } ?? Int.random(in: heroes.indices)]
        let backdrop = Backdrop(frame: content.bounds)
        if let path = nonEmpty(hero.image) { backdrop.hero = NSImage(contentsOfFile: resolve(path)) }
        content.addSubview(backdrop)

        buildLogo(hero)
        buildPromo()
        buildBar()
    }

    func resolve(_ path: String) -> String { path.hasPrefix("/") ? path : "\(root)/\(path)" }

    // The logo image and the slogan, centered where the hero puts them; a slogan
    // with no place of its own sits under the logo.
    func buildLogo(_ hero: Hero) {
        var logoBottom = CGFloat(140)
        let logoX = hero.logo?.x ?? 300, logoY = hero.logo?.y ?? 130
        if let path = nonEmpty(config.logo?.image), let image = NSImage(contentsOfFile: resolve(path)),
           let rep = image.representations.first, rep.pixelsWide > 0 {
            let width = config.logo?.width ?? 460
            let height = width * CGFloat(rep.pixelsHigh) / CGFloat(rep.pixelsWide)
            let view = NSImageView(frame: NSRect(x: logoX - width / 2, y: logoY - height / 2,
                                                 width: width, height: height))
            view.image = image
            view.imageScaling = .scaleAxesIndependently
            content.addSubview(view)
            // The image keeps room for its shadow under the pommel; tuck the slogan into it.
            logoBottom = view.frame.maxY - height * 0.06
        }
        guard let text = nonEmpty(config.slogan?.text) else { return }
        let slogan = Slogan(text, size: config.slogan?.size ?? 13, rule: config.slogan?.rule ?? 120)
        let size = slogan.frame.size
        let x = hero.slogan?.x ?? logoX, y = hero.slogan?.y ?? logoBottom + size.height / 2
        slogan.setFrameOrigin(NSPoint(x: (x - size.width / 2).rounded(), y: (y - size.height / 2).rounded()))
        content.addSubview(slogan)
    }

    // The promo above the bar; with the logo and slogan, the only things drawn over the art.
    func buildPromo() {
        let promo = config.promo
        let title = nonEmpty(promo?.title), text = nonEmpty(promo?.text)
        guard title != nil || text != nil else { return }
        let width: CGFloat = 400, pad: CGFloat = 14
        let card = Panel(frame: .zero)
        card.fill = srgb(0, 0, 0, 0.62)
        var x = pad
        var image: NSImage?
        if let path = nonEmpty(promo?.image) {
            image = NSImage(contentsOfFile: resolve(path))
        }
        let imageSide: CGFloat = 56
        if let image {
            let view = NSImageView(frame: NSRect(x: pad, y: pad, width: imageSide, height: imageSide))
            view.image = image
            view.imageScaling = .scaleProportionallyUpOrDown
            card.addSubview(view)
            x += imageSide + 12
        }
        var y = pad
        if let title {
            let t = label(title, size: 14, color: gold, weight: .semibold, width: width - x - pad)
            t.setFrameOrigin(NSPoint(x: x, y: y))
            card.addSubview(t)
            y = t.frame.maxY + 4
        }
        if let text {
            let t = label(text, size: 12, color: cream, width: width - x - pad)
            t.setFrameOrigin(NSPoint(x: x, y: y))
            card.addSubview(t)
            y = t.frame.maxY
        }
        let height = max(y, image != nil ? pad + imageSide : 0) + pad
        card.frame = NSRect(x: margin, y: windowSize.height - barHeight - 24 - height, width: width, height: height)
        if let url = nonEmpty(promo?.url) {
            card.onClick = { openURL(url) }
            card.toolTip = url
        }
        content.addSubview(card)
    }

    func buildBar() {
        let bar = Bar(frame: NSRect(x: 0, y: windowSize.height - barHeight, width: windowSize.width, height: barHeight))
        content.addSubview(bar)
        let mid = windowSize.height - barHeight / 2

        play.target = self
        play.action = #selector(playPressed)
        play.keyEquivalent = "\r"
        play.isBordered = false
        play.focusRingType = .none
        let inset = PlayButton.glowInset
        play.frame = NSRect(x: windowSize.width - margin - 190 - inset, y: mid - 24 - inset,
                            width: 190 + inset * 2, height: 48 + inset * 2)
        content.addSubview(play)

        let more = linkButton("···", target: self, action: #selector(showMenu(_:)))
        more.attributedTitle = NSAttributedString(string: "···", attributes: [
            .font: NSFont.systemFont(ofSize: 20, weight: .bold), .foregroundColor: cream,
        ])
        more.sizeToFit()
        more.toolTip = "更多"
        var right = play.frame.minX + inset - 22
        more.frame = NSRect(x: right - more.frame.width, y: mid - more.frame.height / 2 - 2,
                            width: more.frame.width, height: more.frame.height)
        content.addSubview(more)
        right = more.frame.minX - 18

        for (i, link) in (config.links ?? []).enumerated().reversed() {
            guard let title = nonEmpty(link.title), let url = nonEmpty(link.url) else { continue }
            links.append(url)
            let button = linkButton(title, target: self, action: #selector(linkPressed(_:)))
            button.tag = links.count - 1
            button.toolTip = url
            button.frame.origin = NSPoint(x: right - button.frame.width, y: mid - button.frame.height / 2)
            content.addSubview(button)
            right = button.frame.minX - (i > 0 ? 16 : 0)
        }

        status.font = .systemFont(ofSize: 14, weight: .semibold)
        status.textColor = cream
        status.frame = NSRect(x: margin, y: mid - 20, width: right - margin - 20, height: 20)
        content.addSubview(status)
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = muted
        detail.lineBreakMode = .byTruncatingHead
        detail.frame = NSRect(x: margin, y: mid + 2, width: right - margin - 20, height: 16)
        content.addSubview(detail)
    }

    // MARK: State

    func set(_ new: ServerState, detail text: String = "") {
        state = new
        detail.stringValue = text
        let mid = windowSize.height - barHeight / 2
        status.frame.origin.y = text.isEmpty ? mid - 10 : mid - 20
        switch new {
        case .starting:
            status.stringValue = "正在启动服务器…"
            play.title = wantsPlay ? "正在进入…" : "开始游戏"
            play.isEnabled = !wantsPlay
        case .ready:
            status.stringValue = "服务器已就绪"
            play.title = "开始游戏"
            play.isEnabled = true
            if wantsPlay { exit(0) }
        case .stopping:
            status.stringValue = "正在关闭服务器…"
            play.isEnabled = false
        case .stopped:
            status.stringValue = "服务器已关闭"
            play.title = "开始游戏"
            play.isEnabled = true
        case .failed(let code):
            status.stringValue = "服务器启动失败（退出码 \(code)）"
            play.title = "重试"
            play.isEnabled = true
            wantsPlay = false
        }
        play.needsDisplay = true
    }

    func run(_ script: String, _ args: [String] = [], done: @escaping (Int32) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["\(root)/tools/macos/\(script)"] + args
        process.currentDirectoryURL = URL(fileURLWithPath: root)
        process.terminationHandler = { p in
            let code = p.terminationStatus
            DispatchQueue.main.async { done(code) }
        }
        do {
            try process.run()
        } catch {
            fputs("launcher: \(script): \(error)\n", stderr)
            done(127)
        }
    }

    func startServer() {
        set(.starting)
        run("play.sh", ["--no-client"]) { code in
            if code == 0 {
                self.set(.ready)
            } else {
                self.set(.failed(code), detail: self.logTail())
            }
        }
    }

    // The last line the server scripts wrote; the launch script points our output at launcher.log.
    func logTail() -> String {
        let path = "\(root)/server/logs/launcher.log"
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return "详情见 server/logs/launcher.log" }
        let last = text.split(separator: "\n").last.map(String.init) ?? ""
        return last.isEmpty ? "详情见 server/logs/launcher.log" : last
    }

    // MARK: Actions

    @objc func playPressed() {
        switch state {
        case .ready: exit(0)
        case .starting:
            wantsPlay = true
            set(.starting)
        case .stopped, .failed:
            wantsPlay = true
            startServer()
        case .stopping: break
        }
    }

    @objc func linkPressed(_ sender: NSButton) {
        if links.indices.contains(sender.tag) { openURL(links[sender.tag]) }
    }

    @objc func showMenu(_ sender: NSButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: "打开日志文件夹", action: #selector(openLogs), keyEquivalent: "").target = self
        menu.addItem(withTitle: "打开插件文件夹", action: #selector(openAddOns), keyEquivalent: "").target = self
        menu.addItem(withTitle: "编辑启动器设置", action: #selector(editConfig), keyEquivalent: "").target = self
        menu.addItem(.separator())
        let stop = menu.addItem(withTitle: "关闭服务器", action: #selector(stopServer), keyEquivalent: "")
        stop.target = self
        if case .ready = state {} else { stop.isEnabled = false }
        menu.autoenablesItems = false
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc func openLogs() { NSWorkspace.shared.open(URL(fileURLWithPath: "\(root)/server/logs")) }

    @objc func openAddOns() {
        let path = "\(root)/benilla-config/AddOns"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    // Seeded with "skip" alone: a key written here replaces the repo's, so a full
    // copy would pin every other key to the day it was made.
    @objc func editConfig() {
        let local = "\(root)/benilla-config/launcher.json"
        if !FileManager.default.fileExists(atPath: local) {
            FileManager.default.createFile(atPath: local, contents: Data("{\n  \"skip\": false\n}\n".utf8))
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: local))
    }

    @objc func stopServer() {
        wantsPlay = false
        set(.stopping)
        run("stop-server.sh") { _ in self.set(.stopped) }
    }

    // MARK: App

    func applicationDidFinishLaunching(_ note: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu()
        appItem.submenu?.addItem(withTitle: "退出 Soloroth", action: #selector(NSApplication.terminate(_:)),
                                 keyEquivalent: "q")
        menu.addItem(appItem)
        NSApp.mainMenu = menu

        build()
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(play)
        NSApp.activate(ignoringOtherApps: true)
        startServer()
    }

    // Quitting here never starts the game: the launch script reads 1 as "stop".
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { exit(1) }
    func windowWillClose(_ note: Notification) { exit(1) }
}

// MARK: - Main

let app = NSApplication.shared
let launcher = Launcher()

if let out = snapshotPath {
    launcher.build()
    launcher.set(.ready)
    let view = launcher.content
    let scale: CGFloat = 2
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(windowSize.width * scale),
                                     pixelsHigh: Int(windowSize.height * scale), bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
    rep.size = windowSize
    view.cacheDisplay(in: view.bounds, to: rep)
    guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
    do {
        try png.write(to: URL(fileURLWithPath: out))
    } catch {
        fputs("could not write \(out): \(error)\n", stderr)
        exit(1)
    }
    exit(0)
}

if launcher.config.skip == true { exit(2) }
app.setActivationPolicy(.regular)
app.delegate = launcher
app.run()

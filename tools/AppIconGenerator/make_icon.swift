// AppIcon generator for gh-notch.
//
// Draws the app icon entirely in CoreGraphics — a dark squircle (superellipse,
// macOS Big Sur style) with a white "notch" pill hanging from the top edge and a
// four-point AI sparkle, echoing the command bar's sparkle motif. No external
// assets, fonts, or services: the icon is fully reproducible from this file.
//
// Usage (run from the repo root):
//   swift tools/AppIconGenerator/make_icon.swift            # regenerate the shipped AppIcon
//   swift tools/AppIconGenerator/make_icon.swift variants   # render colorway variants to /tmp
//
// The shipped colorway is `styles[shippedStyleIndex]` ("blue-indigo").
// This file lives under tools/ and is excluded from SwiftLint (it is not app code).

import CoreGraphics
import Foundation
import ImageIO

// MARK: - Color helpers

let srgb = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return CGColor(colorSpace: srgb, components: [r, g, b, a]) ?? CGColor(gray: 0, alpha: a)
}

// MARK: - Paths (all in y-up coordinates)

func superellipse(cx: CGFloat, cy: CGFloat, halfW: CGFloat, halfH: CGFloat, n: Double = 5.0, steps: Int = 720) -> CGPath {
    let path = CGMutablePath()
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2.0 * Double.pi
        let ct = cos(t), st = sin(t)
        let x = cx + halfW * CGFloat(copysign(pow(abs(ct), 2.0 / n), ct))
        let y = cy + halfH * CGFloat(copysign(pow(abs(st), 2.0 / n), st))
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

/// Notch shape: flat top, fully-rounded bottom corners (hangs from the top like
/// the MacBook camera notch).
func notchPill(cx: CGFloat, topY: CGFloat, w: CGFloat, h: CGFloat) -> CGPath {
    let left = cx - w / 2, right = cx + w / 2
    let top = topY, bottom = topY - h
    let rt = h * 0.20
    let rb = h * 0.50
    let p = CGMutablePath()
    p.move(to: CGPoint(x: left + rt, y: top))
    p.addLine(to: CGPoint(x: right - rt, y: top))
    p.addQuadCurve(to: CGPoint(x: right, y: top - rt), control: CGPoint(x: right, y: top))
    p.addLine(to: CGPoint(x: right, y: bottom + rb))
    p.addQuadCurve(to: CGPoint(x: right - rb, y: bottom), control: CGPoint(x: right, y: bottom))
    p.addLine(to: CGPoint(x: left + rb, y: bottom))
    p.addQuadCurve(to: CGPoint(x: left, y: bottom + rb), control: CGPoint(x: left, y: bottom))
    p.addLine(to: CGPoint(x: left, y: top - rt))
    p.addQuadCurve(to: CGPoint(x: left + rt, y: top), control: CGPoint(x: left, y: top))
    p.closeSubpath()
    return p
}

/// Four-point sparkle with concave curved sides.
func sparkle(cx: CGFloat, cy: CGFloat, r: CGFloat, controlRatio: CGFloat = 0.14) -> CGPath {
    let cr = r * controlRatio
    let tipAng: [CGFloat] = [90, 0, 270, 180].map { $0 * .pi / 180 }
    let bisAng: [CGFloat] = [45, 315, 225, 135].map { $0 * .pi / 180 }
    let tips = tipAng.map { CGPoint(x: cx + r * cos($0), y: cy + r * sin($0)) }
    let p = CGMutablePath()
    p.move(to: tips[0])
    for k in 0..<4 {
        let next = tips[(k + 1) % 4]
        let b = bisAng[k]
        let ctrl = CGPoint(x: cx + cr * cos(b), y: cy + cr * sin(b))
        p.addQuadCurve(to: next, control: ctrl)
    }
    p.closeSubpath()
    return p
}

// MARK: - Style

struct Style {
    let name: String
    let topHex: UInt32
    let botHex: UInt32
    let glowHex: UInt32?
    let accent: Bool
}

let styles: [Style] = [
    Style(name: "v1-slate-indigo", topHex: 0x262A33, botHex: 0x0B0C10, glowHex: 0x5B6CFF, accent: true),
    Style(name: "v2-blue-indigo", topHex: 0x1A2336, botHex: 0x070A12, glowHex: 0x6172FF, accent: true),
    Style(name: "v3-near-black", topHex: 0x1B1B20, botHex: 0x050506, glowHex: 0x5B6CFF, accent: false),
    Style(name: "v4-slate-noglow", topHex: 0x262A33, botHex: 0x0B0C10, glowHex: nil, accent: false),
    Style(name: "v5-slate-teal", topHex: 0x222831, botHex: 0x080A0C, glowHex: 0x35D6C3, accent: true),
    Style(name: "v6-graphite", topHex: 0x2E323B, botHex: 0x101218, glowHex: 0x6E7BFF, accent: false)
]

let shippedStyleIndex = 1

// MARK: - Render

func render(_ style: Style, size s: CGFloat) -> CGImage? {
    let dim = Int(s)
    guard let ctx = CGContext(
        data: nil, width: dim, height: dim, bitsPerComponent: 8, bytesPerRow: 0,
        space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)

    let margin = s * 0.0975
    let l = s - 2 * margin
    let cx = s / 2
    let cyS = s / 2
    let half = l / 2
    let sqTop = cyS + half
    let squircle = superellipse(cx: cx, cy: cyS, halfW: half, halfH: half)

    // Drop shadow cast by the squircle.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.018), blur: s * 0.05, color: color(0x000000, 0.50))
    ctx.addPath(squircle)
    ctx.setFillColor(color(style.botHex))
    ctx.fillPath()
    ctx.restoreGState()

    // Vertical gradient fill.
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    if let grad = CGGradient(colorsSpace: srgb, colors: [color(style.topHex), color(style.botHex)] as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(grad, start: CGPoint(x: cx, y: sqTop), end: CGPoint(x: cx, y: cyS - half), options: [])
    }
    ctx.restoreGState()

    // Subtle top sheen.
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    if let sheen = CGGradient(colorsSpace: srgb, colors: [color(0xFFFFFF, 0.10), color(0xFFFFFF, 0.0)] as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(sheen, start: CGPoint(x: cx, y: sqTop), end: CGPoint(x: cx, y: sqTop - l * 0.45), options: [])
    }
    ctx.restoreGState()

    // Brand glow behind the sparkle.
    let sparkCx = cx
    let sparkCy = cyS - l * 0.04
    if let g = style.glowHex {
        ctx.saveGState()
        ctx.addPath(squircle)
        ctx.clip()
        if let glow = CGGradient(colorsSpace: srgb, colors: [color(g, 0.55), color(g, 0.0)] as CFArray, locations: [0, 1]) {
            ctx.drawRadialGradient(glow, startCenter: CGPoint(x: sparkCx, y: sparkCy), startRadius: 0,
                                   endCenter: CGPoint(x: sparkCx, y: sparkCy), endRadius: l * 0.44, options: [])
        }
        ctx.restoreGState()
    }

    // Notch pill — hangs near the top edge.
    let pw = l * 0.44
    let ph = l * 0.125
    let pillTop = sqTop - l * 0.075
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.006), blur: s * 0.012, color: color(0x000000, 0.35))
    ctx.addPath(notchPill(cx: cx, topY: pillTop, w: pw, h: ph))
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()

    // Sparkle(s).
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: l * 0.025, color: color(0xFFFFFF, 0.55))
    ctx.addPath(sparkle(cx: sparkCx, cy: sparkCy, r: l * 0.20))
    if style.accent {
        ctx.addPath(sparkle(cx: sparkCx + l * 0.175, cy: sparkCy + l * 0.15, r: l * 0.062))
    }
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

// MARK: - Main

let args = CommandLine.arguments
let mode = args.count > 1 ? args[1] : "icon"

if mode == "variants" {
    let outDir = URL(fileURLWithPath: "/tmp/ghicon/variants")
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    for style in styles {
        if let img = render(style, size: 512) {
            writePNG(img, to: outDir.appendingPathComponent("\(style.name).png"))
            print("rendered \(style.name)")
        }
    }
} else {
    // Default: regenerate the shipped AppIcon slots in the asset catalog.
    let defaultOut = "gh-notch/Resources/Assets.xcassets/AppIcon.appiconset"
    let outDir = URL(fileURLWithPath: args.count > 1 ? args[1] : defaultOut)
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let style = styles[shippedStyleIndex]
    // (slot filename, pixel size)
    let slots: [(String, CGFloat)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32),
        ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256),
        ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024)
    ]
    for (name, px) in slots {
        if let img = render(style, size: px) {
            writePNG(img, to: outDir.appendingPathComponent("\(name).png"))
            print("rendered \(name).png (\(Int(px))px) from \(style.name)")
        }
    }
}

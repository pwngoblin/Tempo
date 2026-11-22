// macOS icon options. Usage: swift mac_options.swift <out-dir>  → mac-options/ALL.png + M1…M5.png (1024, mac shape)
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ h: UInt32, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: cs, components: [CGFloat((h >> 16) & 255) / 255, CGFloat((h >> 8) & 255) / 255, CGFloat(h & 255) / 255, a])! }
func grad(_ c: [UInt32]) -> CGGradient { CGGradient(colorsSpace: cs, colors: c.map { rgb($0) } as CFArray, locations: nil)! }
func rr(_ r: CGRect, _ c: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: c, cornerHeight: c, transform: nil) }
func label(_ g: CGContext, _ s: String, _ size: CGFloat, _ p: CGPoint) {
    let f = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, s as CFString, [kCTFontAttributeName: f, kCTForegroundColorAttributeName: rgb(0x1C1C1E)] as CFDictionary))
    let b = CTLineGetBoundsWithOptions(line, .useOpticalBounds); g.textPosition = CGPoint(x: p.x - b.midX, y: p.y - b.midY); CTLineDraw(line, g)
}

struct Style { var bg: [UInt32]; var dot: UInt32; var dotA: CGFloat; var today: UInt32; var ring: Bool; var depth: Bool; var dotR: CGFloat; var topRow: UInt32? = nil }
func art(_ g: CGContext, _ s: Style) {
    g.drawLinearGradient(grad(s.bg), start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    if s.depth {   // soft top light
        g.drawRadialGradient(CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF, 0.16), rgb(0xFFFFFF, 0)] as CFArray, locations: nil)!, startCenter: CGPoint(x: 400, y: 960), startRadius: 0, endCenter: CGPoint(x: 400, y: 960), endRadius: 760, options: [])
    }
    for r in 0..<5 { for c in 0..<5 {
        let p = CGPoint(x: 220 + CGFloat(c) * 146, y: 220 + CGFloat(r) * 146)
        if r == 2 && c == 2 {
            if s.ring {
                g.saveGState(); if s.depth { g.setShadow(offset: .zero, blur: 40, color: rgb(s.today, 0.7)) }
                g.setStrokeColor(rgb(s.today)); g.setLineWidth(20); g.strokeEllipse(in: CGRect(x: p.x - 62, y: p.y - 62, width: 124, height: 124)); g.restoreGState()
                g.setFillColor(rgb(s.today)); g.fillEllipse(in: CGRect(x: p.x - 30, y: p.y - 30, width: 60, height: 60))
            } else {
                g.saveGState(); g.setShadow(offset: .zero, blur: 46, color: rgb(s.today, 0.8)); g.setFillColor(rgb(s.today)); g.fillEllipse(in: CGRect(x: p.x - 66, y: p.y - 66, width: 132, height: 132)); g.restoreGState()
            }
        } else {
            g.saveGState()
            if s.depth { g.setShadow(offset: CGSize(width: 0, height: -6), blur: 10, color: rgb(0x000000, 0.35)) }
            if let t = s.topRow, r == 4 { g.setFillColor(rgb(t, 0.95)) } else { g.setFillColor(rgb(s.dot, s.dotA)) }; g.fillEllipse(in: CGRect(x: p.x - s.dotR, y: p.y - s.dotR, width: 2 * s.dotR, height: 2 * s.dotR)); g.restoreGState()
        }
    } }
}
func mac(_ s: Style) -> CGImage {
    let g = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let shape = rr(CGRect(x: 100, y: 100, width: 824, height: 824), 186)
    g.saveGState(); g.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0x000000, 0.4)); g.addPath(shape); g.setFillColor(rgb(s.bg[0])); g.fillPath(); g.restoreGState()
    g.saveGState(); g.addPath(shape); g.clip(); g.translateBy(x: 100, y: 100); g.scaleBy(x: 824.0 / 1024, y: 824.0 / 1024); art(g, s); g.restoreGState()
    // glossy rim like system icons
    g.saveGState(); g.addPath(shape); g.clip()
    g.setStrokeColor(rgb(0xFFFFFF, 0.28)); g.setLineWidth(4); g.addPath(rr(CGRect(x: 102, y: 102, width: 820, height: 820), 184)); g.strokePath(); g.restoreGState()
    return g.makeImage()!
}
let items: [(String, Style)] = [
 ("M1 Dark (current)", Style(bg: [0x0B0B10, 0x1B1B26], dot: 0xFFFFFF, dotA: 0.55, today: 0xFF453A, ring: true, depth: false, dotR: 22)),
 ("M2 Light", Style(bg: [0xFAFAFC, 0xDDE0EA], dot: 0x1C1C1E, dotA: 0.5, today: 0xFF3B30, ring: true, depth: false, dotR: 22)),
 ("M3 Dark + depth", Style(bg: [0x2A2D4A, 0x0A0B18], dot: 0xFFFFFF, dotA: 0.82, today: 0xFF5A4F, ring: true, depth: true, dotR: 28)),
 ("M4 Coral", Style(bg: [0xFF7A5C, 0xE8344A], dot: 0xFFFFFF, dotA: 0.8, today: 0xFFFFFF, ring: true, depth: true, dotR: 26)),
 ("M5 Blue", Style(bg: [0x3D9BFF, 0x5B4BE8], dot: 0xFFFFFF, dotA: 0.82, today: 0xFFD60A, ring: true, depth: true, dotR: 26)),
 ("M5 Blue + red top row", Style(bg: [0x3D9BFF, 0x5B4BE8], dot: 0xFFFFFF, dotA: 0.82, today: 0xFFD60A, ring: true, depth: true, dotR: 26, topRow: 0xFF3B30)),
]
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "mac-options"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
let tile: CGFloat = 340, W = Int(CGFloat(items.count) * tile + CGFloat(items.count + 1) * 30), H = 560
let sheet = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
sheet.setFillColor(rgb(0xE9E9EE)); sheet.fill(CGRect(x: 0, y: 0, width: W, height: H))
sheet.setFillColor(rgb(0x2B2B30)); sheet.fill(CGRect(x: 0, y: 0, width: W, height: 150))   // dark "Dock" strip for small sizes
func put(_ img: CGImage, _ rect: CGRect) { sheet.draw(img, in: rect) }
for (i, it) in items.enumerated() {
    let img = mac(it.1)
    let x = 30 + CGFloat(i) * (tile + 30)
    put(img, CGRect(x: x, y: 190, width: tile, height: tile))
    label(sheet, it.0, 24, CGPoint(x: x + tile / 2, y: 175 + tile + 10 > 540 ? 540 : 530 - tile + tile))
    put(img, CGRect(x: x + tile / 2 - 80, y: 20, width: 100, height: 100))   // Dock-size preview
    put(img, CGRect(x: x + tile / 2 + 30, y: 40, width: 48, height: 48))
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(out)/M\(i + 1).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}
let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(out)/ALL.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(d, sheet.makeImage()!, nil); CGImageDestinationFinalize(d)

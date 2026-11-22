// Bold single-motif macOS icon options. Usage: swift bold_options.swift <out-dir>
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

func glyphShadow(_ g: CGContext) { g.setShadow(offset: CGSize(width: 0, height: -16), blur: 28, color: rgb(0x0A1A5C, 0.45)) }
func bg(_ g: CGContext, _ c: [UInt32]) {
    g.drawLinearGradient(grad(c), start: CGPoint(x: 300, y: 1024), end: CGPoint(x: 724, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    g.drawRadialGradient(CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF, 0.22), rgb(0xFFFFFF, 0)] as CFArray, locations: nil)!, startCenter: CGPoint(x: 380, y: 980), startRadius: 0, endCenter: CGPoint(x: 380, y: 980), endRadius: 800, options: [])
}
let blue = [0x4DA3FF, 0x3B4FE0] as [UInt32], coral: UInt32 = 0xFF6B5A

// B1 — one bold ring (a day in progress), coral cap
func b1(_ g: CGContext) {
    bg(g, blue); let c = CGPoint(x: 512, y: 512), R: CGFloat = 270, w: CGFloat = 130
    g.saveGState(); glyphShadow(g); g.setLineCap(.round); g.setLineWidth(w); g.setStrokeColor(rgb(0xFFFFFF))
    g.addArc(center: c, radius: R, startAngle: .pi / 2, endAngle: .pi / 2 - 4.5, clockwise: true); g.strokePath(); g.restoreGState()
    let a = CGFloat.pi / 2 - 4.5; let p = CGPoint(x: c.x + R * cos(a), y: c.y + R * sin(a))
    g.setFillColor(rgb(coral)); g.fillEllipse(in: CGRect(x: p.x - 65, y: p.y - 65, width: 130, height: 130))
}
// B2 — three bold agenda blocks
func b2(_ g: CGContext) {
    bg(g, blue)
    let bars: [(CGFloat, CGFloat, UInt32)] = [(210, 470, 0xFFFFFF), (330, 600, coral), (210, 400, 0xFFFFFF)]   // x offset, width, color
    for (i, b) in bars.enumerated() {
        let y = 640 - CGFloat(i) * 190
        g.saveGState(); glyphShadow(g); g.addPath(rr(CGRect(x: b.0 + (i == 1 ? 0 : 0), y: y, width: b.1 - (i == 1 ? 0 : 0) + (i == 1 ? 0 : 0), height: 150), 75)); g.setFillColor(rgb(b.2)); g.fillPath(); g.restoreGState()
    }
}
// B3 — a "T" made of two blocks
func b3(_ g: CGContext) {
    bg(g, blue)
    g.saveGState(); glyphShadow(g); g.setFillColor(rgb(0xFFFFFF))
    g.addPath(rr(CGRect(x: 214, y: 640, width: 596, height: 160), 80)); g.fillPath(); g.restoreGState()
    g.saveGState(); glyphShadow(g); g.setFillColor(rgb(coral))
    g.addPath(rr(CGRect(x: 432, y: 214, width: 160, height: 470), 80)); g.fillPath(); g.restoreGState()
}
func mac(_ art: (CGContext) -> Void) -> CGImage {
    let g = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let shape = rr(CGRect(x: 100, y: 100, width: 824, height: 824), 186)
    g.saveGState(); g.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0x000000, 0.4)); g.addPath(shape); g.setFillColor(rgb(0x3B4FE0)); g.fillPath(); g.restoreGState()
    g.saveGState(); g.addPath(shape); g.clip(); g.translateBy(x: 100, y: 100); g.scaleBy(x: 824.0 / 1024, y: 824.0 / 1024); art(g); g.restoreGState()
    g.saveGState(); g.addPath(shape); g.clip(); g.setStrokeColor(rgb(0xFFFFFF, 0.28)); g.setLineWidth(4); g.addPath(rr(CGRect(x: 102, y: 102, width: 820, height: 820), 184)); g.strokePath(); g.restoreGState()
    return g.makeImage()!
}
let items: [(String, (CGContext) -> Void)] = [("B1 Ring", b1), ("B2 Blocks", b2), ("B3 T-blocks", b3)]
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "bold-options"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
let tile: CGFloat = 400, W = Int(3 * tile + 4 * 30), H = 640
let sheet = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
sheet.setFillColor(rgb(0xE9E9EE)); sheet.fill(CGRect(x: 0, y: 0, width: W, height: H))
sheet.setFillColor(rgb(0x2B2B30)); sheet.fill(CGRect(x: 0, y: 0, width: W, height: 150))
for (i, it) in items.enumerated() {
    let img = mac(it.1); let x = 30 + CGFloat(i) * (tile + 30)
    sheet.draw(img, in: CGRect(x: x, y: 190, width: tile, height: tile))
    label(sheet, it.0, 28, CGPoint(x: x + tile / 2, y: 610))
    sheet.draw(img, in: CGRect(x: x + tile / 2 - 90, y: 20, width: 100, height: 100)); sheet.draw(img, in: CGRect(x: x + tile / 2 + 30, y: 40, width: 48, height: 48))
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(out)/B\(i + 1).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}
let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(out)/ALL.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(d, sheet.makeImage()!, nil); CGImageDestinationFinalize(d)

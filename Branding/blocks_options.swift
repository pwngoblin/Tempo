// Blocks refinements macOS icon options. Usage: swift bold_options.swift <out-dir>
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


var shapeFill: UInt32 = 0x3B4FE0
func block(_ g: CGContext, _ r: CGRect, _ top: UInt32, _ bot: UInt32, shadow: CGColor, glow: CGColor? = nil) {
    let p = rr(r, r.height / 2)
    g.saveGState(); g.setShadow(offset: CGSize(width: 0, height: -14), blur: 26, color: shadow); g.addPath(p); g.setFillColor(rgb(bot)); g.fillPath(); g.restoreGState()
    g.saveGState(); g.addPath(p); g.clip(); g.drawLinearGradient(grad([top, bot]), start: CGPoint(x: 0, y: r.maxY), end: CGPoint(x: 0, y: r.minY), options: [])
    g.setStrokeColor(rgb(0xFFFFFF, 0.55)); g.setLineWidth(3); g.addPath(rr(r.insetBy(dx: 1.5, dy: 1.5), r.height / 2 - 1.5)); g.strokePath(); g.restoreGState()
}
func soft(_ g: CGContext, _ c: [UInt32]) {
    g.drawLinearGradient(grad(c), start: CGPoint(x: 300, y: 1024), end: CGPoint(x: 724, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    g.drawRadialGradient(CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF, 0.2), rgb(0xFFFFFF, 0)] as CFArray, locations: nil)!, startCenter: CGPoint(x: 380, y: 980), startRadius: 0, endCenter: CGPoint(x: 380, y: 980), endRadius: 800, options: [])
}
let H0: CGFloat = 170, gap: CGFloat = 60
func rows(_ g: CGContext, _ spec: [(CGFloat, CGFloat, UInt32, UInt32)], _ sh: CGColor) {
    let total = CGFloat(spec.count) * H0 + CGFloat(spec.count - 1) * gap; var y = 512 + total / 2 - H0
    for b in spec { block(g, CGRect(x: b.0, y: y, width: b.1, height: H0), b.2, b.3, shadow: sh); y -= H0 + gap }
}
func c1(_ g: CGContext) { shapeFill = 0x3B4FE0; soft(g, [0x4DA3FF, 0x3B4FE0])
    rows(g, [(200, 500, 0xFFFFFF, 0xDCE8FF), (324, 500, 0xFF8A78, 0xFF5544), (200, 380, 0xFFFFFF, 0xDCE8FF)], rgb(0x0A1A5C, 0.45)) }
func c2(_ g: CGContext) { shapeFill = 0x0B0B18; soft(g, [0x25274A, 0x08080F])
    rows(g, [(200, 500, 0xFF8A78, 0xFF453A), (324, 500, 0xFFD060, 0xFF9F0A), (200, 380, 0x6FE3FF, 0x2D9CFF)], rgb(0x000000, 0.5)) }
func c3(_ g: CGContext) { shapeFill = 0xDADDE8; soft(g, [0xFFFFFF, 0xDADDE8])
    rows(g, [(200, 500, 0x6FB4FF, 0x2F7BFF), (324, 500, 0xFF8A78, 0xFF453A), (200, 380, 0x6EE29A, 0x22B85A)], rgb(0x1A2A5C, 0.3)) }
func mac(_ art: (CGContext) -> Void) -> CGImage {
    let g = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let shape = rr(CGRect(x: 100, y: 100, width: 824, height: 824), 186)
    g.saveGState(); g.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0x000000, 0.4)); g.addPath(shape); g.setFillColor(rgb(0x3B4FE0)); g.fillPath(); g.restoreGState()
    g.saveGState(); g.addPath(shape); g.clip(); g.translateBy(x: 100, y: 100); g.scaleBy(x: 824.0 / 1024, y: 824.0 / 1024); art(g); g.restoreGState()
    g.saveGState(); g.addPath(shape); g.clip(); g.setStrokeColor(rgb(0xFFFFFF, 0.28)); g.setLineWidth(4); g.addPath(rr(CGRect(x: 102, y: 102, width: 820, height: 820), 184)); g.strokePath(); g.restoreGState()
    return g.makeImage()!
}
let items: [(String, (CGContext) -> Void)] = [("C1 Blue glass", c1), ("C2 Midnight color", c2), ("C3 Light color", c3)]
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "blocks-options"
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
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(out)/C\(i + 1).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}
let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(out)/ALL.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(d, sheet.makeImage()!, nil); CGImageDestinationFinalize(d)

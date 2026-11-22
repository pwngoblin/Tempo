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

func page(_ g: CGContext, card: UInt32, cardBot: UInt32, header: [UInt32], bars: [(UInt32, UInt32)], pegs: UInt32, glass: Bool = false) {
    let r = CGRect(x: 180, y: 190, width: 664, height: 650), cp = rr(r, 120)
    g.saveGState(); g.setShadow(offset: CGSize(width: 0, height: -20), blur: 36, color: rgb(0x0A1040, 0.45)); g.addPath(cp); g.setFillColor(rgb(cardBot)); g.fillPath(); g.restoreGState()
    g.saveGState(); g.addPath(cp); g.clip()
    g.drawLinearGradient(grad([card, cardBot]), start: CGPoint(x: 0, y: r.maxY), end: CGPoint(x: 0, y: r.minY), options: [])
    g.drawLinearGradient(grad(header), start: CGPoint(x: 0, y: r.maxY), end: CGPoint(x: 0, y: r.maxY - 165), options: [])
    g.setFillColor(rgb(0xFFFFFF, 0.35)); g.fill(CGRect(x: r.minX, y: r.maxY - 167, width: r.width, height: 3))
    g.restoreGState()
    let xs: [(CGFloat, CGFloat)] = [(250, 330), (290, 380), (250, 240)]
    for (k, b) in xs.enumerated() { block(g, CGRect(x: b.0 + (k == 1 ? 60 : 0), y: 520 - CGFloat(k) * 150, width: b.1 + 120, height: 100), bars[k].0, bars[k].1, shadow: rgb(0x1A2A5C, 0.25)) }
    for px in [330.0, 694.0] {   // binder pegs
        let pr = CGRect(x: CGFloat(px) - 26, y: r.maxY - 70, width: 52, height: 120)
        g.saveGState(); g.setShadow(offset: CGSize(width: 0, height: -8), blur: 14, color: rgb(0x000000, 0.35)); g.addPath(rr(pr, 26)); g.setFillColor(rgb(pegs)); g.fillPath(); g.restoreGState()
    }
}
func d1(_ g: CGContext) { shapeFill = 0x3B4FE0; soft(g, [0x4DA3FF, 0x3B4FE0])
    page(g, card: 0xFFFFFF, cardBot: 0xE6ECFA, header: [0xFF8A78, 0xFF5544], bars: [(0x6FB4FF, 0x2F7BFF), (0xFFD060, 0xFF9F0A), (0x6EE29A, 0x22B85A)], pegs: 0xFFFFFF) }
func d2(_ g: CGContext) { shapeFill = 0x0B0B18; soft(g, [0x25274A, 0x08080F])
    page(g, card: 0x34385E, cardBot: 0x1E2040, header: [0xFF8A78, 0xFF453A], bars: [(0x6FE3FF, 0x2D9CFF), (0xFFD060, 0xFF9F0A), (0x6EE29A, 0x22B85A)], pegs: 0xE8EAF5) }
func d3(_ g: CGContext) { shapeFill = 0xDADDE8; soft(g, [0xFFFFFF, 0xDADDE8])
    page(g, card: 0xFFFFFF, cardBot: 0xF3F4F8, header: [0x5AA2FF, 0x2F6BF0], bars: [(0xFF8A78, 0xFF453A), (0xFFD060, 0xFF9F0A), (0x6EE29A, 0x22B85A)], pegs: 0x9AA3B8) }
func mac(_ art: (CGContext) -> Void) -> CGImage {
    let g = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let shape = rr(CGRect(x: 100, y: 100, width: 824, height: 824), 186)
    g.saveGState(); g.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0x000000, 0.4)); g.addPath(shape); g.setFillColor(rgb(0x3B4FE0)); g.fillPath(); g.restoreGState()
    g.saveGState(); g.addPath(shape); g.clip(); g.translateBy(x: 100, y: 100); g.scaleBy(x: 824.0 / 1024, y: 824.0 / 1024); art(g); g.restoreGState()
    g.saveGState(); g.addPath(shape); g.clip(); g.setStrokeColor(rgb(0xFFFFFF, 0.28)); g.setLineWidth(4); g.addPath(rr(CGRect(x: 102, y: 102, width: 820, height: 820), 184)); g.strokePath(); g.restoreGState()
    return g.makeImage()!
}
let items: [(String, (CGContext) -> Void)] = [("D1 Blue + page", d1), ("D2 Midnight page", d2), ("D3 Light page", d3)]
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "page-options"
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
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(out)/D\(i + 1).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}
let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(out)/ALL.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(d, sheet.makeImage()!, nil); CGImageDestinationFinalize(d)

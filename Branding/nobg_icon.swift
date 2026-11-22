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


func icon() -> CGImage {
    let g = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let r = CGRect(x: 100, y: 100, width: 824, height: 824), shape = rr(r, 186)
    g.saveGState(); g.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0x000000, 0.4)); g.addPath(shape); g.setFillColor(rgb(0xE6ECFA)); g.fillPath(); g.restoreGState()
    g.saveGState(); g.addPath(shape); g.clip()
    g.drawLinearGradient(grad([0xFFFFFF, 0xE6ECFA]), start: CGPoint(x: 0, y: r.maxY), end: CGPoint(x: 0, y: r.minY), options: [])
    g.drawLinearGradient(grad([0xFF8A78, 0xFF5544]), start: CGPoint(x: 0, y: r.maxY), end: CGPoint(x: 0, y: r.maxY - 210), options: [])
    g.setFillColor(rgb(0xFFFFFF, 0.35)); g.fill(CGRect(x: r.minX, y: r.maxY - 212, width: r.width, height: 3))
    g.restoreGState()
    for px in [345.0, 679.0] {
        let pr = CGRect(x: CGFloat(px) - 28, y: r.maxY - 150, width: 56, height: 120)
        g.saveGState(); g.setShadow(offset: CGSize(width: 0, height: -8), blur: 14, color: rgb(0x000000, 0.3)); g.addPath(rr(pr, 28)); g.setFillColor(rgb(0xFFFFFF)); g.fillPath(); g.restoreGState()
    }
    let bars: [(CGFloat, CGFloat, UInt32, UInt32)] = [(210, 380, 0x6FB4FF, 0x2F7BFF), (320, 400, 0xFFD060, 0xFF9F0A), (210, 290, 0x6EE29A, 0x22B85A)]
    for (k, b) in bars.enumerated() { block(g, CGRect(x: b.0, y: 545 - CGFloat(k) * 170, width: b.1, height: 115), b.2, b.3, shadow: rgb(0x1A2A5C, 0.25)) }
    g.saveGState(); g.addPath(shape); g.clip(); g.setStrokeColor(rgb(0xFFFFFF, 0.5)); g.setLineWidth(4); g.addPath(rr(r.insetBy(dx: 2, dy: 2), 184)); g.strokePath(); g.restoreGState()
    return g.makeImage()!
}
let img = icon()
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "nobg-options"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(out)/E1.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)

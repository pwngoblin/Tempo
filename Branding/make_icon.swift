// Tempo app icon = "Midnight grid, ring on today" (owner's pick, 2026-11-22). Core Graphics only.
// Usage: swift make_icon.swift <out-dir>   → AppIcon-{light,dark,tinted}-1024.png (iOS/watch, full-bleed) + AppIcon-macOS-{dark,light}-1024.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let S = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ h: UInt32, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: cs, components: [CGFloat((h >> 16) & 255) / 255, CGFloat((h >> 8) & 255) / 255, CGFloat(h & 255) / 255, a])! }
func grad(_ c: [UInt32]) -> CGGradient { CGGradient(colorsSpace: cs, colors: c.map { rgb($0) } as CFArray, locations: [0, 1])! }
func rr(_ r: CGRect, _ c: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: c, cornerHeight: c, transform: nil) }

struct Look { var bg: [UInt32]; var dot: UInt32; var dotAlpha: CGFloat; var today: UInt32; var gray: Bool }
let dark = Look(bg: [0x0B0B10, 0x1B1B26], dot: 0xFFFFFF, dotAlpha: 0.55, today: 0xFF453A, gray: false)
let light = Look(bg: [0xF7F7FA, 0xE2E4EC], dot: 0x1C1C1E, dotAlpha: 0.5, today: 0xFF3B30, gray: false)
let tinted = Look(bg: [0x000000, 0x000000], dot: 0xFFFFFF, dotAlpha: 0.5, today: 0xFFFFFF, gray: true)   // iOS tints grayscale art itself

func art(_ g: CGContext, _ l: Look) {
    g.drawLinearGradient(grad(l.bg), start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    for r in 0..<5 { for c in 0..<5 {
        let p = CGPoint(x: 220 + CGFloat(c) * 146, y: 220 + CGFloat(r) * 146)
        if r == 2 && c == 2 {
            g.setStrokeColor(rgb(l.today)); g.setLineWidth(18); g.strokeEllipse(in: CGRect(x: p.x - 58, y: p.y - 58, width: 116, height: 116))
            g.setFillColor(rgb(l.today)); g.fillEllipse(in: CGRect(x: p.x - 26, y: p.y - 26, width: 52, height: 52))
        } else {
            g.setFillColor(rgb(l.dot, l.dotAlpha)); g.fillEllipse(in: CGRect(x: p.x - 22, y: p.y - 22, width: 44, height: 44))
        }
    } }
}
func ctx() -> CGContext { CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)! }
func full(_ l: Look) -> CGImage { let g = ctx(); art(g, l); return g.makeImage()! }
func mac(_ l: Look) -> CGImage {
    let g = ctx(), shape = rr(CGRect(x: 100, y: 100, width: 824, height: 824), 186)
    g.saveGState(); g.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
    g.addPath(shape); g.setFillColor(rgb(l.bg[0])); g.fillPath(); g.restoreGState()
    g.saveGState(); g.addPath(shape); g.clip(); g.translateBy(x: 100, y: 100); g.scaleBy(x: 824.0 / 1024, y: 824.0 / 1024); art(g, l); g.restoreGState()
    g.setStrokeColor(rgb(l.gray || l.bg[0] > 0x800000 ? 0x000000 : 0xFFFFFF, 0.10)); g.setLineWidth(2); g.addPath(shape); g.strokePath()
    return g.makeImage()!
}
func write(_ img: CGImage, _ path: String) {
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
write(full(light), out + "/AppIcon-light-1024.png"); write(full(dark), out + "/AppIcon-dark-1024.png"); write(full(tinted), out + "/AppIcon-tinted-1024.png")
write(mac(dark), out + "/AppIcon-macOS-dark-1024.png"); write(mac(light), out + "/AppIcon-macOS-light-1024.png")

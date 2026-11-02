// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import AppKit
let output = CommandLine.arguments[1]
func draw(_ pixels: Int, path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let tile = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 192, yRadius: 192)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.22); shadow.shadowOffset = NSSize(width: 0, height: -14); shadow.shadowBlurRadius = 25; shadow.set()
    NSColor(calibratedRed: 0.06, green: 0.27, blue: 0.28, alpha: 1).setFill(); tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.57, blue: 0.51, alpha: 1), ending: NSColor(calibratedRed: 0.04, green: 0.29, blue: 0.32, alpha: 1))!.draw(in: tile, angle: -65)
    NSColor.white.withAlphaComponent(0.19).setStroke(); tile.lineWidth = 3; tile.stroke()
    // A clear clipboard silhouette: paperwork and completed milestones.
    let paper = NSBezierPath(roundedRect: NSRect(x: 264, y: 222, width: 496, height: 575), xRadius: 58, yRadius: 58)
    NSGraphicsContext.saveGraphicsState()
    let paperShadow = NSShadow(); paperShadow.shadowColor = NSColor.black.withAlphaComponent(0.20); paperShadow.shadowOffset = NSSize(width: 0, height: -16); paperShadow.shadowBlurRadius = 20; paperShadow.set()
    NSColor(calibratedWhite: 0.98, alpha: 1).setFill(); paper.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor(calibratedRed: 0.68, green: 0.86, blue: 0.80, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 396, y: 750, width: 232, height: 92), xRadius: 28, yRadius: 28).fill()
    NSColor(calibratedRed: 0.11, green: 0.40, blue: 0.38, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 465, y: 782, width: 94, height: 21), xRadius: 10, yRadius: 10).fill()
    let ink = NSColor(calibratedRed: 0.13, green: 0.46, blue: 0.42, alpha: 1)
    for y: CGFloat in [649, 526] {
        let check = NSBezierPath(); check.move(to: NSPoint(x: 333, y: y - 2)); check.line(to: NSPoint(x: 357, y: y - 25)); check.line(to: NSPoint(x: 400, y: y + 24)); check.lineWidth = 22; check.lineCapStyle = .round; check.lineJoinStyle = .round; ink.setStroke(); check.stroke()
        NSColor(calibratedRed: 0.64, green: 0.72, blue: 0.71, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 447, y: y - 13, width: 213, height: 24), xRadius: 12, yRadius: 12).fill()
    }
    // A warm progress bar remains recognizable at small Dock sizes.
    NSColor(calibratedRed: 0.87, green: 0.91, blue: 0.88, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 333, y: 344, width: 335, height: 55), xRadius: 27, yRadius: 27).fill()
    NSColor(calibratedRed: 0.94, green: 0.68, blue: 0.30, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 333, y: 344, width: 246, height: 55), xRadius: 27, yRadius: 27).fill()
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
for size in [16, 32, 128, 256, 512] {
    draw(size, path: output + "/icon_\(size)x\(size).png")
    draw(size * 2, path: output + "/icon_\(size)x\(size)@2x.png")
}

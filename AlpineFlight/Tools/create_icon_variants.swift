import AppKit
import Foundation

// Offline vector artwork, rasterized once for Xcode. No animation or work at runtime.
let assets = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let manager = FileManager.default
func save(_ data: Data, name: String, appIcon: Bool) throws {
    let folder = assets.appendingPathComponent(name + (appIcon ? ".appiconset" : ".imageset"))
    try manager.createDirectory(at: folder, withIntermediateDirectories: true)
    try data.write(to: folder.appendingPathComponent("Icon.png"))
    var image: [String: String] = ["filename": "Icon.png", "idiom": "universal"]
    if appIcon { image["platform"] = "ios"; image["size"] = "1024x1024" }
    let contents: [String: Any] = ["images": [image], "info": ["author": "xcode", "version": 1]]
    try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("Contents.json"))
}
func artwork(gold: Bool) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.setFillColor(NSColor(red: 0.025, green: 0.045, blue: 0.1, alpha: 1).cgColor)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let accent = gold ? NSColor(red: 1, green: 0.77, blue: 0.28, alpha: 1) : NSColor(red: 0.3, green: 0.85, blue: 1, alpha: 1)
    for i in 0..<60 {
        let angle = CGFloat(i) * 2 * .pi / 60
        let radius: CGFloat = CGFloat(210 + (i * 37) % 150)
        let end = gold ? radius + 4 : radius + CGFloat(60 + (i * 23) % 160)
        context.setStrokeColor(accent.withAlphaComponent(gold ? 0.7 : 0.45).cgColor)
        context.setLineWidth(gold ? 5 : 3)
        context.move(to: CGPoint(x: 512 + cos(angle) * radius, y: 480 + sin(angle) * radius))
        context.addLine(to: CGPoint(x: 512 + cos(angle) * end, y: 480 + sin(angle) * end))
        context.strokePath()
    }
    if gold {
        context.setStrokeColor(accent.cgColor); context.setLineWidth(12)
        context.strokeEllipse(in: CGRect(x: 125, y: 125, width: 774, height: 774))
    }
    // An original starfighter emblem, rather than a film ship model.
    let points: [CGPoint] = [CGPoint(x: 512, y: 810), CGPoint(x: 566, y: 553), CGPoint(x: 811, y: 287),
                             CGPoint(x: 592, y: 371), CGPoint(x: 555, y: 248), CGPoint(x: 469, y: 248),
                             CGPoint(x: 432, y: 371), CGPoint(x: 213, y: 287), CGPoint(x: 458, y: 553)]
    context.setShadow(offset: .zero, blur: 25, color: accent.withAlphaComponent(0.65).cgColor)
    context.setFillColor(accent.cgColor)
    context.addLines(between: points); context.closePath(); context.fillPath()
    context.setShadow(offset: .zero, blur: 0)
    context.setFillColor(NSColor(red: 0.04, green: 0.12, blue: 0.2, alpha: 1).cgColor)
    context.fillEllipse(in: CGRect(x: 492, y: 448, width: 40, height: 143))
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
try save(Data(contentsOf: assets.appendingPathComponent("AppIcon.appiconset/AppIcon.png")), name: "IconPreview_classic", appIcon: false)
for (name, gold) in [("hyperspace", false), ("gold", true)] {
    let image = artwork(gold: gold)
    try save(image, name: gold ? "GoldIcon" : "HyperspaceIcon", appIcon: true)
    try save(image, name: "IconPreview_" + name, appIcon: false)
}

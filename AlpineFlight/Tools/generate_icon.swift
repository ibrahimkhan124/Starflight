import AppKit

let size = 1024
let canvas = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let context = NSGraphicsContext(cgContext: canvas, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
NSColor(red: 0.06, green: 0.15, blue: 0.17, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()
func polygon(_ points: [CGPoint], _ color: NSColor) {
    let path = NSBezierPath()
    path.move(to: points[0])
    for point in points.dropFirst() { path.line(to: point) }
    path.close()
    color.setFill()
    path.fill()
}
polygon([CGPoint(x: 50, y: 180), CGPoint(x: 370, y: 685), CGPoint(x: 570, y: 370), CGPoint(x: 710, y: 560), CGPoint(x: 1000, y: 180)], NSColor(red: 0.39, green: 0.59, blue: 0.52, alpha: 1))
polygon([CGPoint(x: 281, y: 545), CGPoint(x: 370, y: 685), CGPoint(x: 460, y: 543), CGPoint(x: 386, y: 575), CGPoint(x: 350, y: 550), CGPoint(x: 323, y: 574)], NSColor(red: 0.89, green: 0.94, blue: 0.87, alpha: 1))
polygon([CGPoint(x: 526, y: 585), CGPoint(x: 666, y: 778), CGPoint(x: 674, y: 887), CGPoint(x: 698, y: 899), CGPoint(x: 712, y: 784), CGPoint(x: 876, y: 623), CGPoint(x: 865, y: 597), CGPoint(x: 715, y: 690), CGPoint(x: 715, y: 585), CGPoint(x: 758, y: 548), CGPoint(x: 751, y: 525), CGPoint(x: 689, y: 550), CGPoint(x: 630, y: 516), CGPoint(x: 619, y: 537), CGPoint(x: 663, y: 582), CGPoint(x: 663, y: 688), CGPoint(x: 547, y: 565)], NSColor(red: 0.97, green: 0.71, blue: 0.36, alpha: 1))
NSGraphicsContext.restoreGraphicsState()
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let bitmap = NSBitmapImageRep(cgImage: canvas.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: url)

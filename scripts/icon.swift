import AppKit
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(srgbRed: 0.045, green: 0.065, blue: 0.08, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let lime = NSColor(srgbRed: 0.80, green: 0.96, blue: 0.36, alpha: 1)
lime.setStroke()
let ring = NSBezierPath(ovalIn: NSRect(x: 202, y: 202, width: 620, height: 620))
ring.lineWidth = 64
ring.stroke()
let spokes = NSBezierPath()
spokes.lineWidth = 64
spokes.lineCapStyle = .round
spokes.move(to: NSPoint(x: 216, y: 555))
spokes.line(to: NSPoint(x: 808, y: 555))
spokes.move(to: NSPoint(x: 512, y: 535))
spokes.line(to: NSPoint(x: 512, y: 218))
spokes.stroke()
lime.setFill()
NSBezierPath(roundedRect: NSRect(x: 402, y: 448, width: 220, height: 174), xRadius: 62, yRadius: 62).fill()
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "ios/ShiftLog/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))

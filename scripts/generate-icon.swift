import AppKit

// Use the same SF Symbol as the menu bar, rendered into standard macOS icon sizes.
let output = CommandLine.arguments.dropFirst().first ?? "/tmp/AIbar.iconset"
let manager = FileManager.default
try manager.createDirectory(atPath: output, withIntermediateDirectories: true)
let sizes = [16, 32, 128, 256, 512]
for size in sizes {
    for scale in [1, 2] {
        let pixels = size * scale
        let dimension = CGFloat(pixels)
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                             isPlanar: false, colorSpaceName: .deviceRGB,
                                             bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot create bitmap") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let tile = NSRect(x: dimension * 0.08, y: dimension * 0.08,
                          width: dimension * 0.84, height: dimension * 0.84)
        let path = NSBezierPath(roundedRect: tile, xRadius: dimension * 0.19, yRadius: dimension * 0.19)
        let gradient = NSGradient(starting: NSColor(srgbRed: 0.13, green: 0.19, blue: 0.23, alpha: 1),
                                  ending: NSColor(srgbRed: 0.045, green: 0.075, blue: 0.10, alpha: 1))!
        gradient.draw(in: path, angle: -90)
        let config = NSImage.SymbolConfiguration(pointSize: dimension * 0.49, weight: .medium)
            .applying(.init(paletteColors: [NSColor(srgbRed: 0.35, green: 0.90, blue: 0.76, alpha: 1)]))
        guard let symbol = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { fatalError("Missing menu bar symbol") }
        let ratio = min(dimension * 0.57 / symbol.size.width, dimension * 0.57 / symbol.size.height)
        let symbolSize = NSSize(width: symbol.size.width * ratio, height: symbol.size.height * ratio)
        symbol.draw(in: NSRect(x: (dimension - symbolSize.width) / 2,
                               y: (dimension - symbolSize.height) / 2,
                               width: symbolSize.width, height: symbolSize.height))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot render icon") }
        let suffix = scale == 2 ? "@2x" : ""
        try png.write(to: URL(fileURLWithPath: "\(output)/icon_\(size)x\(size)\(suffix).png"))
    }
}

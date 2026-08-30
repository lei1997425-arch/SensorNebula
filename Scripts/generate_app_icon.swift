import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else { fatalError("No graphics context") }

let colorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
let colors = [
    NSColor.systemCyan.cgColor,
    NSColor.systemPurple.cgColor
] as CFArray
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 110, y: 914),
    end: CGPoint(x: 914, y: 110),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)

let configuration = NSImage.SymbolConfiguration(pointSize: 360, weight: .regular)
    .applying(NSImage.SymbolConfiguration(paletteColors: [
        NSColor(calibratedRed: 0.08, green: 0.07, blue: 0.16, alpha: 1)
    ]))

guard let symbol = NSImage(
    systemSymbolName: "sensor.tag.radiowaves.forward.fill",
    accessibilityDescription: nil
)?.withSymbolConfiguration(configuration) else {
    fatalError("Sensor symbol unavailable")
}

// SwiftUI's Image(systemName:) preserves the symbol's intrinsic aspect ratio.
// Fit it at the same visual scale as the 22 pt symbol inside the 46 pt logo.
let nativeSize = symbol.size
let maximumSize = NSSize(width: 600, height: 470)
let scale = min(maximumSize.width / nativeSize.width, maximumSize.height / nativeSize.height)
let symbolSize = NSSize(width: nativeSize.width * scale, height: nativeSize.height * scale)
let symbolRect = NSRect(
    x: (size.width - symbolSize.width) / 2,
    y: (size.height - symbolSize.height) / 2,
    width: symbolSize.width,
    height: symbolSize.height
)
symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon")
}
try png.write(to: URL(fileURLWithPath: output))

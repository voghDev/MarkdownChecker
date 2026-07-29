#!/usr/bin/swift
import AppKit

func renderIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.22

    // Clip to rounded rect
    let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    bg.addClip()

    // Blue-to-indigo gradient background
    let top    = NSColor(red: 0.20, green: 0.47, blue: 0.95, alpha: 1)
    let bottom = NSColor(red: 0.10, green: 0.26, blue: 0.72, alpha: 1)
    let gradient = NSGradient(starting: top, ending: bottom)!
    gradient.draw(in: rect, angle: -90)

    // White document shape (offset slightly left-centre)
    let docW = size * 0.52
    let docH = size * 0.62
    let docX = (size - docW) / 2 - size * 0.01
    let docY = (size - docH) / 2 - size * 0.02
    let foldSize = docW * 0.28

    let doc = NSBezierPath()
    doc.move(to:    NSPoint(x: docX,                   y: docY))
    doc.line(to:    NSPoint(x: docX + docW - foldSize, y: docY))
    doc.line(to:    NSPoint(x: docX + docW,            y: docY + foldSize))
    doc.line(to:    NSPoint(x: docX + docW,            y: docY + docH))
    doc.line(to:    NSPoint(x: docX,                   y: docY + docH))
    doc.close()
    NSColor.white.withAlphaComponent(0.95).setFill()
    doc.fill()

    // Folded corner crease
    let fold = NSBezierPath()
    fold.move(to:  NSPoint(x: docX + docW - foldSize, y: docY))
    fold.line(to:  NSPoint(x: docX + docW - foldSize, y: docY + foldSize))
    fold.line(to:  NSPoint(x: docX + docW,            y: docY + foldSize))
    NSColor(red: 0.20, green: 0.47, blue: 0.95, alpha: 0.35).setFill()
    fold.fill()

    // "M↓" text on the document
    let fontSize = size * 0.22
    let font = NSFont.boldSystemFont(ofSize: fontSize)
    let color = NSColor(red: 0.12, green: 0.28, blue: 0.75, alpha: 1)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let label = "M↓"
    let labelSize = label.size(withAttributes: attrs)
    let lx = docX + (docW - labelSize.width) / 2 - size * 0.01
    let ly = docY + (docH - labelSize.height) / 2 + size * 0.01
    label.draw(at: NSPoint(x: lx, y: ly), withAttributes: attrs)

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let bmp  = NSBitmapImageRep(data: tiff),
          let png  = bmp.representation(using: .png, properties: [:]) else {
        fputs("Failed to encode \(path)\n", stderr); return
    }
    try! png.write(to: URL(fileURLWithPath: path))
}

let iconsetDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/MarkdownPreview.iconset"
try! FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let specs: [(String, CGFloat)] = [
    ("icon_16x16",      16),  ("icon_16x16@2x",    32),
    ("icon_32x32",      32),  ("icon_32x32@2x",    64),
    ("icon_128x128",   128),  ("icon_128x128@2x", 256),
    ("icon_256x256",   256),  ("icon_256x256@2x", 512),
    ("icon_512x512",   512),  ("icon_512x512@2x",1024),
]

for (name, size) in specs {
    writePNG(renderIcon(size: size), to: "\(iconsetDir)/\(name).png")
}

print(iconsetDir)

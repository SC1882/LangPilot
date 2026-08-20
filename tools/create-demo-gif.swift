import AppKit
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("docs/images/langpilot-demo.gif")
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)

let size = CGSize(width: 900, height: 420)
let scale: CGFloat = 2

struct Frame {
    let typed: String
    let fixed: String?
    let badge: String?
    let caption: String
    let delay: Double
}

let frames: [Frame] = [
    .init(typed: "", fixed: nil, badge: nil, caption: "Type in any app", delay: 0.45),
    .init(typed: "g", fixed: nil, badge: nil, caption: "Type in any app", delay: 0.12),
    .init(typed: "gh", fixed: nil, badge: nil, caption: "Type in any app", delay: 0.12),
    .init(typed: "ghb", fixed: nil, badge: nil, caption: "Type in any app", delay: 0.12),
    .init(typed: "ghbd", fixed: nil, badge: nil, caption: "Type in any app", delay: 0.12),
    .init(typed: "ghbdt", fixed: nil, badge: nil, caption: "Type in any app", delay: 0.12),
    .init(typed: "ghbdtn", fixed: nil, badge: nil, caption: "Wrong layout detected", delay: 0.55),
    .init(typed: "ghbdtn", fixed: "привет", badge: "EN → RU", caption: "LangPilot fixes it locally", delay: 1.15),
    .init(typed: "привет", fixed: nil, badge: "✓ fixed", caption: "No cloud, no accounts, no uploaded text", delay: 1.1),
    .init(typed: "привет", fixed: nil, badge: nil, caption: "Smart typing across languages", delay: 1.0)
]

func roundedRect(_ rect: CGRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

func drawText(_ text: String, in rect: CGRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineBreakMode = .byTruncatingTail
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: style
    ]
    text.draw(in: rect, withAttributes: attributes)
}

func makeFrame(_ frame: Frame) -> CGImage {
    let image = NSImage(size: size)
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let bounds = CGRect(origin: .zero, size: size)
    NSColor(calibratedRed: 0.985, green: 0.988, blue: 0.992, alpha: 1).setFill()
    bounds.fill()

    roundedRect(CGRect(x: 82, y: 64, width: 736, height: 292),
                radius: 28,
                fill: .white,
                stroke: NSColor(calibratedRed: 0.84, green: 0.87, blue: 0.91, alpha: 1),
                lineWidth: 1.5)

    drawText("LangPilot", in: CGRect(x: 122, y: 98, width: 220, height: 42),
             font: .systemFont(ofSize: 29, weight: .bold),
             color: NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.17, alpha: 1))
    drawText("Smart typing across languages", in: CGRect(x: 122, y: 137, width: 360, height: 28),
             font: .systemFont(ofSize: 15, weight: .medium),
             color: .secondaryLabelColor)

    let field = CGRect(x: 122, y: 188, width: 656, height: 76)
    roundedRect(field, radius: 18,
                fill: NSColor(calibratedRed: 0.965, green: 0.975, blue: 0.99, alpha: 1),
                stroke: NSColor(calibratedRed: 0.58, green: 0.72, blue: 0.96, alpha: 1),
                lineWidth: 2)

    let visibleText = frame.fixed ?? frame.typed
    let textColor = frame.fixed == nil
        ? NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1)
        : NSColor(calibratedRed: 0.05, green: 0.34, blue: 0.18, alpha: 1)
    drawText(visibleText, in: CGRect(x: 154, y: 205, width: 520, height: 44),
             font: .monospacedSystemFont(ofSize: 34, weight: .regular),
             color: textColor)

    if frame.fixed == nil {
        let cursorX = 154 + CGFloat(frame.typed.count) * 20
        NSColor(calibratedRed: 0.0, green: 0.38, blue: 0.95, alpha: 1).setFill()
        CGRect(x: cursorX, y: 205, width: 3, height: 39).fill()
    }

    if let fixed = frame.fixed {
        drawText(frame.typed, in: CGRect(x: 154, y: 272, width: 240, height: 24),
                 font: .monospacedSystemFont(ofSize: 16, weight: .regular),
                 color: NSColor(calibratedRed: 0.55, green: 0.58, blue: 0.64, alpha: 1))
        drawText("→ \(fixed)", in: CGRect(x: 260, y: 272, width: 240, height: 24),
                 font: .monospacedSystemFont(ofSize: 16, weight: .semibold),
                 color: NSColor(calibratedRed: 0.05, green: 0.34, blue: 0.18, alpha: 1))
    }

    if let badge = frame.badge {
        roundedRect(CGRect(x: 624, y: 111, width: 122, height: 38),
                    radius: 19,
                    fill: NSColor(calibratedRed: 0.07, green: 0.43, blue: 0.96, alpha: 1))
        drawText(badge, in: CGRect(x: 624, y: 119, width: 122, height: 24),
                 font: .systemFont(ofSize: 14, weight: .bold),
                 color: .white,
                 alignment: .center)
    }

    roundedRect(CGRect(x: 122, y: 295, width: 656, height: 1),
                radius: 0,
                fill: NSColor(calibratedRed: 0.9, green: 0.92, blue: 0.95, alpha: 1))

    drawText(frame.caption, in: CGRect(x: 122, y: 307, width: 656, height: 30),
             font: .systemFont(ofSize: 18, weight: .semibold),
             color: NSColor(calibratedRed: 0.25, green: 0.28, blue: 0.34, alpha: 1),
             alignment: .center)

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let cg = bitmap.cgImage else {
        fatalError("Could not render frame")
    }
    return cg
}

guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
    fatalError("Could not create GIF destination")
}

let gifProperties: [CFString: Any] = [
    kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFLoopCount: 0
    ]
]
CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

for frame in frames {
    let properties: [CFString: Any] = [
        kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: frame.delay
        ]
    ]
    CGImageDestinationAddImage(destination, makeFrame(frame), properties as CFDictionary)
}

guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not finalize GIF")
}

print(output.path)

// Frames raw screenshots for the README and the social preview. No dependencies beyond
// the system frameworks. Built and run by Scripts/screenshots.sh:
//
//   frame hero    <mac.png> <out.png> [height]
//   frame iphone  <out.png> <phone1.png> <phone2.png> <phone3.png>
//   frame social  <mac.png> <icon.png> <out.png>
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: space,
        components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, alpha])!
}

func load(_ path: String) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fatalError("cannot read \(path)") }
    return image
}

func save(_ image: CGImage, _ path: String) {
    guard let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("cannot write \(path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("cannot write \(path)") }
}

func canvas(_ width: Int, _ height: Int, _ draw: (CGContext) -> Void) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    context.setShouldAntialias(true)
    draw(context)
    return context.makeImage()!
}

/// The soft mint-to-cream wash behind the README images.
func background(_ c: CGContext, _ width: Int, _ height: Int) {
    let gradient = CGGradient(colorsSpace: space, colors: [rgb(0xCDE6DF), rgb(0xE3ECE2), rgb(0xF4EBDD)] as CFArray, locations: [0, 0.5, 1])!
    c.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(height)), end: CGPoint(x: CGFloat(width), y: 0), options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
}

func roundedPath(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Draws `image` into `rect` with a soft shadow that follows the image's own alpha. With
/// `radius`, the image is first clipped to a rounded rectangle in a transparent canvas; the
/// clip is anti-aliased, so the corners have no fringe.
func place(_ c: CGContext, _ image: CGImage, in rect: CGRect, radius: CGFloat?, shadow: CGFloat) {
    var shaped = image
    if let radius {
        let scale = CGFloat(image.width) / rect.width
        shaped = canvas(image.width, image.height) { k in
            k.addPath(roundedPath(CGRect(x: 0, y: 0, width: image.width, height: image.height), radius * scale))
            k.clip()
            k.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
    }
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -shadow * 0.45), blur: shadow, color: rgb(0x0B2B29, 0.30))
    c.draw(shaped, in: rect)
    c.restoreGState()
}

let args = CommandLine.arguments
switch args.dropFirst().first {
case "hero":
    // The Mac window's own corners are transparent already, so it is not clipped again.
    let mac = load(args[2])
    let width = 1600, height = args.count > 4 ? Int(args[4])! : 915
    let w: CGFloat = 1240
    let h = w * CGFloat(mac.height) / CGFloat(mac.width)
    let out = canvas(width, height) { c in
        background(c, width, height)
        place(c, mac, in: CGRect(x: (CGFloat(width) - w) / 2, y: (CGFloat(height) - h) / 2, width: w, height: h), radius: nil, shadow: 44)
    }
    save(out, args[3])
case "iphone":
    let phones = args[3...].map(load)
    let width = 1600, height = 1000
    let w: CGFloat = 395
    let gap: CGFloat = 70
    let out = canvas(width, height) { c in
        background(c, width, height)
        let total = w * CGFloat(phones.count) + gap * CGFloat(phones.count - 1)
        for (i, phone) in phones.enumerated() {
            let h = w * CGFloat(phone.height) / CGFloat(phone.width)
            let rect = CGRect(x: (CGFloat(width) - total) / 2 + CGFloat(i) * (w + gap), y: (CGFloat(height) - h) / 2, width: w, height: h)
            place(c, phone, in: rect, radius: w * 0.135, shadow: 36)
        }
    }
    save(out, args[2])
case "social":
    let mac = load(args[2]), icon = load(args[3])
    let width = 1280, height = 640
    let out = canvas(width, height) { c in
        let gradient = CGGradient(colorsSpace: space, colors: [rgb(0xF7F3EA), rgb(0xEFEDE1), rgb(0xD3E7E0)] as CFArray, locations: [0, 0.55, 1])!
        c.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(height)), end: CGPoint(x: CGFloat(width), y: 0), options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        // Icon and name, left.
        let side: CGFloat = 236
        let iconRect = CGRect(x: 118, y: 270, width: side, height: side)
        place(c, icon, in: iconRect, radius: nil, shadow: 30)
        let title = NSAttributedString(
            string: "Quill",
            attributes: [
                .font: NSFont(name: "NewYorkMedium-Bold", size: 74) ?? NSFont(name: "Georgia-Bold", size: 74)!,
                .foregroundColor: NSColor(cgColor: rgb(0x0B6E69))!,
            ])
        let line = CTLineCreateWithAttributedString(title)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        c.textPosition = CGPoint(x: iconRect.midX - bounds.width / 2, y: 170)
        CTLineDraw(line, c)
        // Window, right.
        let w: CGFloat = 760
        let h = w * CGFloat(mac.height) / CGFloat(mac.width)
        place(c, mac, in: CGRect(x: 440, y: (CGFloat(height) - h) / 2, width: w, height: h), radius: nil, shadow: 36)
    }
    save(out, args[4])
default:
    FileHandle.standardError.write(Data("usage: frame hero|iphone|social ...\n".utf8))
    exit(64)
}

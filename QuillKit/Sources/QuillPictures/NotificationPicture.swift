import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The picture a notification shows for a sender: the person's own from the account's
/// contacts, else the logo of the site the mail came from. Nil when there is neither, which
/// leaves the notification with the app icon.
public enum NotificationPicture {
    /// Google serves many real brand icons at 32px, and answers 404 for a site it has no icon for.
    private static let smallestLogo = 32
    private static let side = 256

    /// PNG data, square, ready for a notification.
    public static func data(for address: String, session: URLSession = .shared) async -> Data? {
        let address = address.lowercased()
        if let url = PictureDirectory.photoURL(for: address),
           let image = await image(at: url, session: session, smallestSide: 1) {
            return png(image, onWhite: false)
        }
        if let domain = SenderLogo.domain(for: address), let url = SenderLogo.url(for: domain),
           let image = await image(at: url, session: session, smallestSide: smallestLogo) {
            return png(image, onWhite: true)
        }
        return nil
    }

    private static func image(at url: URL, session: URLSession, smallestSide: Int) async -> CGImage? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        // An icon file can hold several sizes; the largest is the one worth showing.
        let images = (0..<CGImageSourceGetCount(source)).compactMap { CGImageSourceCreateImageAtIndex(source, $0, nil) }
        guard let largest = images.max(by: { $0.width < $1.width }),
              min(largest.width, largest.height) >= smallestSide else { return nil }
        return largest
    }

    /// A person's picture fills the square from the middle. A logo sits whole on white with room around it.
    private static func png(_ image: CGImage, onWhite: Bool) -> Data? {
        let space = CGColorSpace(name: CGColorSpace.sRGB)
        guard let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: space ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let square = CGFloat(side)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: square, height: square))
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let room = onWhite ? square * 0.7 : square
        let scale = onWhite ? min(room / width, room / height) : max(room / width, room / height)
        let drawn = CGSize(width: width * scale, height: height * scale)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: (square - drawn.width) / 2, y: (square - drawn.height) / 2, width: drawn.width, height: drawn.height))
        guard let result = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, result, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}

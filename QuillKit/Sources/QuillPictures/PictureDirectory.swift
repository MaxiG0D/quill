import Foundation

/// The contact pictures Quill has found, kept where the notification extension can read them.
public enum PictureDirectory {
    public static let group = "group.com.maxig0d.quill"

    private static var file: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appending(path: "contact-photos.json")
    }

    /// Replaces the saved pictures, by lowercased address.
    public static func save(_ photos: [String: URL]) {
        guard let file, let data = try? JSONEncoder().encode(photos.mapValues(\.absoluteString)) else { return }
        try? data.write(to: file, options: .atomic)
    }

    public static func clear() {
        guard let file else { return }
        try? FileManager.default.removeItem(at: file)
    }

    public static func photoURL(for address: String) -> URL? {
        guard let file, let data = try? Data(contentsOf: file),
              let photos = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
        return photos[address.lowercased()].flatMap { URL(string: $0) }
    }
}

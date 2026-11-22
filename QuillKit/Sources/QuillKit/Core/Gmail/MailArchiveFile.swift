import Foundation

/// Reads and writes the archive as a file in the app's support folder.
struct MailArchiveFile: Sendable {
    let url: URL

    /// The signed-in account's archive.
    static var standard: MailArchiveFile {
        named("mailbox.json")
    }

    /// A per-account archive file inside Quill's application support folder.
    static func named(_ filename: String) -> MailArchiveFile {
        let folder = URL.applicationSupportDirectory.appending(path: "Quill", directoryHint: .isDirectory)
        return MailArchiveFile(url: folder.appending(path: filename))
    }

    func load() -> MailArchive? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONDecoder().decode(MailArchive.self, from: data))?.current
    }

    func save(_ archive: MailArchive) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(archive).write(to: url, options: .atomic)
    }

    func erase() {
        try? FileManager.default.removeItem(at: url)
    }
}

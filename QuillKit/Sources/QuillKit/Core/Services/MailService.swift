/// The boundary between the app and a mail provider.
///
/// `MailStore` applies every change locally first and then reports it here, so an
/// implementation only has to carry the change to the server and throw if it fails.
protocol MailService: Sendable {
    /// The mailbox as last seen, to show while `snapshot()` is on its way.
    func cachedSnapshot() async -> MailSnapshot?
    func snapshot() async throws -> MailSnapshot
    func apply(_ change: ThreadChange, to ids: [MailThread.ID]) async throws
    func send(_ draft: Draft) async throws
    func search(_ query: String) async throws -> [MailThread]
    /// Makes a label's or mailbox's own mail part of every snapshot from now on, however
    /// old it is. True when the next snapshot will hold more because of it.
    func watch(_ selection: MailboxSelection) async -> Bool
}

extension MailService {
    func cachedSnapshot() async -> MailSnapshot? { nil }
    func watch(_ selection: MailboxSelection) async -> Bool { false }
}

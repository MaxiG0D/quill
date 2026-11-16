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
}

extension MailService {
    func cachedSnapshot() async -> MailSnapshot? { nil }
}

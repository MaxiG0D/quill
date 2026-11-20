import Foundation


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
    /// Fetches one thread by itself and returns the mailbox with it included, without listing
    /// anything else. Nil when the service has no such thread or no mailbox to add it to.
    func fetchThread(_ id: MailThread.ID) async throws -> MailSnapshot?
    /// Tells a mailing list to stop with a single POST to its RFC 8058 address.
    func postOneClickUnsubscribe(to url: URL) async throws
}

extension MailService {
    func cachedSnapshot() async -> MailSnapshot? { nil }
    func watch(_ selection: MailboxSelection) async -> Bool { false }
    func fetchThread(_ id: MailThread.ID) async throws -> MailSnapshot? { nil }
    func postOneClickUnsubscribe(to url: URL) async throws {}

    /// Leaves a mailing list the quietest way it allows: one click, then an email,
    /// then its own page, which only the person can finish.
    func unsubscribe(_ offer: Unsubscribe) async throws -> UnsubscribeOutcome {
        var failure: (any Error)?
        if let url = offer.oneClick {
            do {
                try await postOneClickUnsubscribe(to: url)
                return .done
            } catch {
                failure = error
            }
        }
        if let mail = offer.mail {
            let draft = Draft(
                to: [Contact(name: "", email: mail.address)],
                subject: mail.subject ?? "Unsubscribe",
                body: mail.body ?? "Unsubscribe"
            )
            do {
                try await send(draft)
                return .done
            } catch {
                failure = error
            }
        }
        if let page = offer.page {
            return .openPage(page)
        }
        throw failure ?? GmailError.status(400, "")
    }
}

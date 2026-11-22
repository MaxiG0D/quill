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
    /// Downloads the raw bytes of an attachment.
    func attachmentData(for attachment: Attachment) async throws -> Data
    /// Sends a draft and optionally returns the provider's resulting thread ID.
    func sendDraft(_ draft: Draft) async throws -> MailThread.ID?
    /// Persists a draft to the provider and returns the stored draft thread if created/updated.
    func saveDraft(_ draft: Draft) async throws -> MailThread?
    /// Permanently removes threads from the provider (used for Trash / Empty Trash).
    func deletePermanently(_ ids: [MailThread.ID]) async throws
    /// Marks or unmarks threads as spam.
    func markSpam(_ ids: [MailThread.ID], isSpam: Bool) async throws
    /// Loads the next page of older threads for `selection`, returning newly loaded threads and whether more exist.
    func loadMore(for selection: MailboxSelection) async throws -> (threads: [MailThread], hasMore: Bool)
    /// True when the service knows there is another page of threads for `selection`.
    func hasMore(for selection: MailboxSelection) async -> Bool
    /// Creates a new user label.
    func createLabel(name: String) async throws -> MailLabel
    /// Renames an existing user label.
    func renameLabel(_ id: MailLabel.ID, to name: String) async throws -> MailLabel
    /// Deletes a user label.
    func deleteLabel(_ id: MailLabel.ID) async throws
}

extension MailService {
    func cachedSnapshot() async -> MailSnapshot? { nil }
    func watch(_ selection: MailboxSelection) async -> Bool { false }
    func fetchThread(_ id: MailThread.ID) async throws -> MailSnapshot? { nil }
    func postOneClickUnsubscribe(to url: URL) async throws {}
    func attachmentData(for attachment: Attachment) async throws -> Data {
        if let data = attachment.data { return data }
        throw GmailError.attachmentsUnsupported
    }
    func sendDraft(_ draft: Draft) async throws -> MailThread.ID? {
        try await send(draft)
        return nil
    }
    func saveDraft(_ draft: Draft) async throws -> MailThread? { nil }
    func deletePermanently(_ ids: [MailThread.ID]) async throws {}
    func markSpam(_ ids: [MailThread.ID], isSpam: Bool) async throws {}
    func loadMore(for selection: MailboxSelection) async throws -> (threads: [MailThread], hasMore: Bool) { ([], false) }
    func hasMore(for selection: MailboxSelection) async -> Bool { false }
    func createLabel(name: String) async throws -> MailLabel {
        MailLabel(id: UUID().uuidString, name: name, tone: .stable(for: name))
    }
    func renameLabel(_ id: MailLabel.ID, to name: String) async throws -> MailLabel {
        MailLabel(id: id, name: name, tone: .stable(for: name))
    }
    func deleteLabel(_ id: MailLabel.ID) async throws {}

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

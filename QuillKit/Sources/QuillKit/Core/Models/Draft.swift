import Foundation

struct Draft: Identifiable, Hashable, Sendable {
    let id: String
    var to: [Contact]
    var cc: [Contact]
    var subject: String
    var body: String
    var attachments: [Attachment]
    /// The thread this draft answers, if any.
    var threadID: MailThread.ID?
    /// Text carried along from the message being answered or forwarded.
    var quoted: String?

    init(
        id: String = UUID().uuidString,
        to: [Contact] = [],
        cc: [Contact] = [],
        subject: String = "",
        body: String = "",
        attachments: [Attachment] = [],
        threadID: MailThread.ID? = nil,
        quoted: String? = nil
    ) {
        self.id = id
        self.to = to
        self.cc = cc
        self.subject = subject
        self.body = body
        self.attachments = attachments
        self.threadID = threadID
        self.quoted = quoted
    }

    var canSend: Bool { !to.isEmpty }

    var isEmpty: Bool {
        to.isEmpty && cc.isEmpty && attachments.isEmpty
            && subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A reply to the latest message. `all` keeps everyone else on the thread.
    static func reply(to thread: MailThread, from account: Contact, all: Bool = false) -> Draft {
        guard let latest = thread.latest else { return Draft(threadID: thread.id) }
        let author = latest.sender == account ? latest.to : [latest.sender]
        var cc: [Contact] = []
        if all {
            cc = (latest.to + latest.cc).filter { $0 != account && !author.contains($0) }
        }
        return Draft(
            to: author,
            cc: cc,
            subject: prefixed(thread.subject, with: "Re:"),
            threadID: thread.id,
            quoted: latest.body
        )
    }

    /// A forward of the latest message, attachments included.
    static func forward(_ thread: MailThread) -> Draft {
        Draft(
            subject: prefixed(thread.subject, with: "Fwd:"),
            attachments: thread.latest?.attachments ?? [],
            quoted: thread.latest?.body
        )
    }

    private static func prefixed(_ subject: String, with prefix: String) -> String {
        subject.lowercased().hasPrefix(prefix.lowercased()) ? subject : "\(prefix) \(subject)"
    }
}

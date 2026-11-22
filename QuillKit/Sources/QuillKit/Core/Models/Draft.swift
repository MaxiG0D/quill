import Foundation

struct Draft: Identifiable, Hashable, Sendable {
    let id: String
    var to: [Contact]
    var cc: [Contact]
    var bcc: [Contact]
    var subject: String
    var body: String
    /// Formatted HTML version of `body` when rich styles were applied in the composer.
    var htmlBody: String?
    var attachments: [Attachment]
    /// The thread this draft answers, if any.
    var threadID: MailThread.ID?
    /// True when forwarding a message rather than starting a new conversation.
    var isForward: Bool
    /// The draft thread being resumed from the Drafts mailbox, if any.
    var sourceDraftThreadID: MailThread.ID?
    /// Text carried along from the message being answered or forwarded.
    var quoted: String?

    init(
        id: String = UUID().uuidString,
        to: [Contact] = [],
        cc: [Contact] = [],
        bcc: [Contact] = [],
        subject: String = "",
        body: String = "",
        htmlBody: String? = nil,
        attachments: [Attachment] = [],
        threadID: MailThread.ID? = nil,
        isForward: Bool = false,
        sourceDraftThreadID: MailThread.ID? = nil,
        quoted: String? = nil
    ) {
        self.id = id
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
        self.htmlBody = htmlBody
        self.attachments = attachments
        self.threadID = threadID
        self.isForward = isForward
        self.sourceDraftThreadID = sourceDraftThreadID
        self.quoted = quoted
    }

    var title: String {
        if isForward { return "Forward" }
        return threadID == nil ? "New Message" : "Reply"
    }

    var canSend: Bool { !to.isEmpty || !cc.isEmpty || !bcc.isEmpty }

    var isEmpty: Bool {
        to.isEmpty && cc.isEmpty && bcc.isEmpty && attachments.isEmpty
            && subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A reply to the latest message. `all` keeps everyone else on the thread.
    static func reply(to thread: MailThread, from account: Contact, all: Bool = false) -> Draft {
        guard let latest = thread.latest else { return Draft(threadID: thread.id) }
        return reply(to: latest, in: thread, from: account, all: all)
    }

    /// A reply to a specific message inside a thread.
    static func reply(to message: Message, in thread: MailThread, from account: Contact, all: Bool = false) -> Draft {
        let me = account.email.lowercased()
        let isFromMe = message.sender.email.lowercased() == me
        let author = isFromMe ? message.to : [message.sender]
        let authorEmails = Set(author.map { $0.email.lowercased() })
        var cc: [Contact] = []
        if all {
            var seen = authorEmails
            seen.insert(me)
            for contact in message.to + message.cc {
                let email = contact.email.lowercased()
                if seen.insert(email).inserted {
                    cc.append(contact)
                }
            }
        }
        return Draft(
            to: author,
            cc: cc,
            subject: prefixed(thread.subject, with: "Re:"),
            threadID: thread.id,
            quoted: message.body
        )
    }

    /// A forward of the latest message, attachments included.
    static func forward(_ thread: MailThread) -> Draft {
        guard let latest = thread.latest else {
            return Draft(subject: prefixed(thread.subject, with: "Fwd:"), isForward: true)
        }
        return forward(latest, in: thread)
    }

    /// A forward of a specific message inside a thread, attachments included.
    static func forward(_ message: Message, in thread: MailThread) -> Draft {
        Draft(
            subject: prefixed(thread.subject, with: "Fwd:"),
            attachments: message.attachments,
            isForward: true,
            quoted: message.body
        )
    }

    /// Reopens a saved draft thread in the composer.
    static func editing(_ thread: MailThread) -> Draft {
        let message = thread.latest
        return Draft(
            to: message?.to ?? [],
            cc: message?.cc ?? [],
            subject: thread.subject,
            body: message?.body ?? "",
            attachments: message?.attachments ?? [],
            sourceDraftThreadID: thread.id,
            quoted: message?.quoted
        )
    }

    private static func prefixed(_ subject: String, with prefix: String) -> String {
        subject.lowercased().hasPrefix(prefix.lowercased()) ? subject : "\(prefix) \(subject)"
    }
}

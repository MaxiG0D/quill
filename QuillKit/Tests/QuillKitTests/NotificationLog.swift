import Foundation
@testable import QuillKit

/// Stands in for the system's notifications, and remembers what it was asked to show.
actor NotificationLog: NotificationPosting {
    private var answer: NotificationPermission
    /// What the person answers when the system asks.
    private let reply: NotificationPermission
    private(set) var posted: [NewMail] = []
    private(set) var badge: Int?
    private(set) var kept: Set<MailThread.ID>?
    private(set) var requests = 0

    init(_ answer: NotificationPermission = .allowed, reply: NotificationPermission = .allowed) {
        self.answer = answer
        self.reply = reply
    }

    func permission() -> NotificationPermission { answer }

    func requestPermission() -> NotificationPermission {
        requests += 1
        answer = reply
        return reply
    }

    func post(_ mail: [NewMail]) {
        posted += mail
    }

    func setBadge(_ count: Int) {
        badge = count
    }

    func withdraw(keeping threadIDs: Set<MailThread.ID>) {
        kept = threadIDs
    }
}

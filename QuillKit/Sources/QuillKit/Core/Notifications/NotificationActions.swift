import UserNotifications

/// The buttons on Quill's alerts: Archive and Delete on new mail, and Copy first on a sign-in code.
/// Neither opens Quill; the change goes to Gmail from the background.
enum NotificationActions {
    /// New mail without a sign-in code. The relay sends the same identifier.
    static let mailCategory = "NEW_MAIL"
    static let archive = "ARCHIVE"
    static let delete = "DELETE"

    /// Carries out Archive and Delete through the account.
    @MainActor private static var perform: (@MainActor (_ threadID: MailThread.ID, _ mailbox: Mailbox) async -> Void)?

    /// Tells the system about every alert's buttons, and which account files the mail. Called
    /// before the app finishes launching, so alerts that arrive while it is closed carry them.
    @MainActor
    static func register(filing perform: @escaping @MainActor (_ threadID: MailThread.ID, _ mailbox: Mailbox) async -> Void) {
        // SwiftUI may build the scene again; the first account is the one it keeps.
        if self.perform == nil {
            self.perform = perform
        }
        let archive = UNNotificationAction(identifier: Self.archive, title: "Archive", options: [], icon: UNNotificationActionIcon(systemImageName: Mailbox.archive.symbol))
        let delete = UNNotificationAction(identifier: Self.delete, title: "Delete", options: [.destructive], icon: UNNotificationActionIcon(systemImageName: Mailbox.trash.symbol))
        let copy = UNNotificationAction(identifier: CodeCopying.action, title: "Copy", options: [], icon: UNNotificationActionIcon(systemImageName: "doc.on.doc"))
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: mailCategory, actions: [archive, delete], intentIdentifiers: []),
            UNNotificationCategory(identifier: CodeCopying.category, actions: [copy, archive, delete], intentIdentifiers: []),
        ])
    }

    /// Where an action files the thread, or nil for any other response.
    static func mailbox(for actionIdentifier: String) -> Mailbox? {
        switch actionIdentifier {
        case archive: .archive
        case delete: .trash
        default: nil
        }
    }

    @MainActor
    static func file(_ threadID: MailThread.ID, in mailbox: Mailbox) async {
        guard !threadID.isEmpty else { return }
        await perform?(threadID, mailbox)
    }
}

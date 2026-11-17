import QuillPictures
import UserNotifications

/// Gives each new-mail alert the sender's picture before it is shown, and leaves it as it
/// came, with the app icon, when there is no picture or time runs out.
final class NotificationService: UNNotificationServiceExtension, @unchecked Sendable {
    private let lock = NSLock()
    private var handler: ((UNNotificationContent) -> Void)?
    private var original: UNNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        let content = request.content
        lock.withLock {
            handler = contentHandler
            original = content
        }
        guard let address = content.userInfo["sender"] as? String, !address.isEmpty else {
            finish(content)
            return
        }
        Task {
            guard let picture = await NotificationPicture.data(for: address) else {
                finish(content)
                return
            }
            finish(CommunicationNotification.decorate(content, sender: content.title, address: address, picture: picture))
        }
    }

    override func serviceExtensionTimeWillExpire() {
        let content = lock.withLock { original }
        if let content { finish(content) }
    }

    /// Hands the alert over once, whichever of the picture and the clock comes first.
    private func finish(_ content: UNNotificationContent) {
        let deliver = lock.withLock {
            defer { handler = nil }
            return handler
        }
        deliver?(content)
    }
}

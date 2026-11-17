import QuillPictures
import UserNotifications

/// Notifications through the system's notification center.
///
/// A notification's thread identifier is its Quill thread ID, which groups a conversation's
/// notifications and tells `NotificationTaps` what to open.
struct SystemNotifications: NotificationPosting {
    private var center: UNUserNotificationCenter { .current() }

    func permission() async -> NotificationPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: .undecided
        case .denied: .denied
        default: .allowed
        }
    }

    func requestPermission() async -> NotificationPermission {
        let isGranted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        return isGranted ? .allowed : .denied
    }

    func post(_ mail: [NewMail]) async {
        for item in mail {
            let content = UNMutableNotificationContent()
            content.title = item.sender
            if let digits = item.code {
                content.body = SignInCode(digits: digits).display
                content.categoryIdentifier = CodeCopying.category
                content.userInfo["code"] = digits
            } else {
                content.subtitle = item.subject
                content.body = item.preview
            }
            content.sound = .default
            content.threadIdentifier = item.threadID
            // The message ID keeps a message from being shown twice.
            var shown: UNNotificationContent = content
            if !item.address.isEmpty, let picture = await NotificationPicture.data(for: item.address) {
                shown = CommunicationNotification.decorate(content, sender: item.sender, address: item.address, picture: picture)
            }
            let request = UNNotificationRequest(identifier: item.messageID, content: shown, trigger: nil)
            try? await center.add(request)
        }
    }

    func setBadge(_ count: Int) async {
        try? await center.setBadgeCount(count)
    }

    func withdraw(keeping threadIDs: Set<MailThread.ID>) async {
        let stale = await center.deliveredNotifications()
            .filter { !threadIDs.contains($0.request.content.threadIdentifier) }
            .map(\.request.identifier)
        guard !stale.isEmpty else { return }
        center.removeDeliveredNotifications(withIdentifiers: stale)
    }
}

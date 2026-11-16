/// The boundary between Quill and the system's notifications.
protocol NotificationPosting: Sendable {
    func permission() async -> NotificationPermission
    /// Shows the system's prompt, and returns the answer.
    func requestPermission() async -> NotificationPermission
    func post(_ mail: [NewMail]) async
    /// Sets the number on the app's icon. Zero clears it.
    func setBadge(_ count: Int) async
    /// Removes delivered notifications for every thread except the ones given.
    func withdraw(keeping threadIDs: Set<MailThread.ID>) async
}

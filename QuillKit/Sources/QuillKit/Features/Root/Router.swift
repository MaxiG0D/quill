import Foundation
import Observation

/// Where the person is in the app: the pushed thread, open sheets and search.
@MainActor
@Observable
final class Router {
    /// The compact layout's navigation path.
    var path: [MailThread.ID] = []
    /// The message being written. Setting it presents the composer.
    var draft: Draft?
    /// A message asked for while another was open, such as a mailto link. It opens once that one closes.
    private(set) var waitingDraft: Draft?
    /// The thread whose custom snooze date/time picker is open.
    var snoozingThreadID: MailThread.ID?
    /// A downloaded attachment file URL presented in QuickLook from the Inbox or thread.
    var previewAttachmentURL: URL?
    var isShowingMailboxes = false
    var isShowingSettings = false
    var isSearching = false

    /// Opens the composer with `draft`, or keeps it for when the message being written closes.
    func compose(_ draft: Draft) {
        if self.draft == nil {
            self.draft = draft
        } else {
            waitingDraft = draft
        }
    }

    /// Opens the message that was waiting, if any. Called once the composer has closed.
    func composeWaitingDraft() {
        guard draft == nil, let waitingDraft else { return }
        self.waitingDraft = nil
        draft = waitingDraft
    }

    /// Clears transient navigation and sheet state (for example on sign-out).
    func reset() {
        path = []
        draft = nil
        waitingDraft = nil
        snoozingThreadID = nil
        previewAttachmentURL = nil
        isShowingMailboxes = false
        isShowingSettings = false
        isSearching = false
    }
}

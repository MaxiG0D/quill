import SwiftUI

/// Launch arguments that put the app in a known state for screenshot tests,
/// for example `-QuillScreen thread -QuillAppearance dark`.
struct LaunchOptions {
    enum Screen: String {
        case inbox, thread, search, compose, mailboxes, settings, zero
    }

    var screen: Screen?
    var colorScheme: ColorScheme?

    init(defaults: UserDefaults = .standard) {
        screen = defaults.string(forKey: "QuillScreen").flatMap(Screen.init)
        colorScheme =
            switch defaults.string(forKey: "QuillAppearance") {
            case "dark": .dark
            case "light": .light
            default: nil
            }
    }

    /// A live store normally. With a screen requested, a store frozen at the moment the mockups show.
    @MainActor
    func makeStore() -> MailStore {
        guard let screen else {
            return MailStore(service: SampleMailService())
        }
        let calendar = Calendar.current
        let now = SampleData.referenceDate(in: calendar)
        var snapshot = SampleData.snapshot(now: now, calendar: calendar)
        if screen == .zero {
            snapshot.threads.removeAll { $0.folder == .inbox }
        }
        let store = MailStore(snapshot: snapshot, calendar: calendar, clock: { now })
        switch screen {
        case .thread:
            store.selectedThreadID = "lease-renewal"
        case .search:
            store.searchQuery = "lease"
            store.search()
        case .inbox, .compose, .mailboxes, .settings, .zero:
            break
        }
        return store
    }

    @MainActor
    func makeRouter() -> Router {
        let router = Router()
        switch screen {
        case .thread:
            router.path = ["lease-renewal"]
        case .search:
            router.isSearching = true
        case .compose:
            router.draft = Draft(
                to: [SampleData.priya, SampleData.haldenLeasing],
                subject: "Re: Lease renewal",
                body: "Hi Priya,\n\nBoth signatures are on the attached copy. Thanks for sending it over so quickly.\n\nMax",
                attachments: [Attachment(id: "signed", filename: "Lease_Renewal_Signed.pdf")]
            )
        case .mailboxes:
            router.isShowingMailboxes = true
        case .settings:
            // The phone layout reaches Settings through the mailboxes drawer.
            router.isShowingMailboxes = true
            router.isShowingSettings = true
        case .inbox, .zero, nil:
            break
        }
        return router
    }
}

import Foundation
import Testing
@testable import QuillKit

@MainActor
struct InboxCategoryTests {
    private func store(filing: [MailThread.ID: Set<InboxCategory>]) -> MailStore {
        var snapshot = Fixture.snapshot
        for index in snapshot.threads.indices {
            if let categories = filing[snapshot.threads[index].id] {
                snapshot.threads[index].categories = categories
            }
        }
        let now = Fixture.now
        return MailStore(snapshot: snapshot, calendar: Fixture.calendar, clock: { now })
    }

    @Test func anInboxWithoutSortedMailShowsNoTabs() {
        let store = Fixture.store()
        #expect(store.inboxCategories.isEmpty)
        #expect(store.unreadCount == 2)
    }

    @Test func theInboxOpensOnPrimaryAndCountsOnlyPrimary() {
        let store = store(filing: ["dental": [.promotions], "holds": [.updates]])
        #expect(store.inboxCategories == [.primary, .promotions, .updates])
        #expect(store.category == .primary)
        let shown = store.visibleThreads.map(\.id)
        #expect(!shown.contains("dental"))
        #expect(!shown.contains("holds"))
        #expect(shown.contains("lease-renewal"))
        #expect(store.unreadCount == 1)
        #expect(store.badge(for: .mailbox(.inbox)) == 1)
    }

    @Test func aTabShowsOnlyItsOwnMail() {
        let store = store(filing: ["dental": [.promotions], "holds": [.updates]])
        store.show(.promotions)
        #expect(store.visibleThreads.map(\.id) == ["dental"])
        #expect(store.unreadCount == 1)
        // Other mailboxes are not narrowed by the tab.
        store.show(.mailbox(.archive))
        #expect(store.visibleThreads.map(\.id).contains("lease-unit"))
    }

    @Test func archivingFromATabLeavesIt() {
        let store = store(filing: ["dental": [.promotions]])
        store.show(.promotions)
        store.archive("dental")
        #expect(store.visibleThreads.isEmpty)
        store.undo()
        #expect(store.visibleThreads.map(\.id) == ["dental"])
    }

    @Test func gmailCategoryLabelsBecomeTabs() {
        #expect(InboxCategory(labelID: "CATEGORY_PROMOTIONS") == .promotions)
        #expect(InboxCategory(labelID: "CATEGORY_PERSONAL") == .primary)
        #expect(InboxCategory(labelID: "INBOX") == nil)
        let legacy = MailThread(subject: "", messages: [])
        var unknown = legacy
        unknown.categories = nil
        #expect(unknown.isFiled(under: .primary))
        #expect(!unknown.isFiled(under: .social))
    }
}

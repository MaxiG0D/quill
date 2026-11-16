import Foundation
import Testing
@testable import QuillKit

@MainActor
struct MailStoreTests {
    @Test func startsOnTheInboxWithTheMockupCounts() {
        let store = Fixture.store()
        #expect(store.phase == .loaded)
        #expect(store.title == "Inbox")
        #expect(store.unreadCount == 2)
        #expect(store.badge(for: .mailbox(.inbox)) == 2)
        #expect(store.badge(for: .mailbox(.snoozed)) == 1)
        #expect(store.badge(for: .mailbox(.drafts)) == 1)
        #expect(store.badge(for: .mailbox(.sent)) == nil)
        #expect(store.badge(for: .label("house")) == 1)
        #expect(store.badge(for: .label("travel")) == nil)
    }

    @Test func archivingRemovesTheThreadAndUndoRestoresIt() {
        let store = Fixture.store()
        store.archive("dental")
        #expect(!store.visibleThreads.map(\.id).contains("dental"))
        #expect(store.thread("dental")?.folder == .archive)
        #expect(store.toast?.title == "Archived")
        #expect(store.unreadCount == 1)

        store.undo()
        #expect(store.visibleThreads.map(\.id).contains("dental"))
        #expect(store.toast == nil)
        #expect(store.unreadCount == 2)
    }

    @Test func trashingTheOpenThreadSelectsItsNeighbor() {
        let store = Fixture.store()
        store.select("dental")
        store.trash("dental")
        #expect(store.selectedThreadID == "library")
        #expect(store.thread("dental")?.folder == .trash)
    }

    @Test func openingAThreadMarksItRead() {
        let store = Fixture.store()
        store.select("lease-renewal")
        #expect(store.thread("lease-renewal")?.isUnread == false)
        #expect(store.unreadCount == 1)
    }

    @Test func starPinAndUnreadToggle() {
        let store = Fixture.store()
        store.toggleStar("hike")
        store.togglePin("hike")
        store.toggleUnread("hike")
        let thread = store.thread("hike")
        #expect(thread?.isStarred == true)
        #expect(thread?.isPinned == true)
        #expect(thread?.isUnread == true)
        #expect(store.sections.first?.threads.map(\.id) == ["lease-renewal", "hike"])
    }

    @Test func filtersNarrowTheList() {
        let store = Fixture.store()
        store.filter = .unread
        #expect(store.visibleThreads.map(\.id) == ["lease-renewal", "dental"])
        store.filter = .attachments
        #expect(store.visibleThreads.map(\.id) == ["lease-renewal", "photos", "water"])
    }

    @Test func switchingMailboxClearsSelectionAndSearch() {
        let store = Fixture.store()
        store.select("dental")
        store.searchQuery = "lease"
        store.show(.label("family"))
        #expect(store.title == "Family")
        #expect(store.selectedThreadID == nil)
        #expect(store.searchQuery.isEmpty)
        #expect(store.visibleThreads.map(\.id) == ["library", "thanksgiving"])
    }

    @Test func snoozingHidesTheThreadUntilLater() {
        let store = Fixture.store()
        store.snooze("hike", until: .tomorrow)
        #expect(!store.visibleThreads.map(\.id).contains("hike"))
        #expect(store.badge(for: .mailbox(.snoozed)) == 2)
        store.undo()
        #expect(store.visibleThreads.map(\.id).contains("hike"))
    }

    @Test func sendingAReplyAddsItToTheThread() async throws {
        let store = Fixture.store()
        let thread = try #require(store.thread("lease-renewal"))
        var draft = Draft.reply(to: thread, from: store.account)
        draft.body = "Signed and attached."

        let sent = await store.send(draft)
        #expect(sent)
        #expect(store.thread("lease-renewal")?.messages.count == 4)
        #expect(store.thread("lease-renewal")?.latest?.sender == store.account)
    }

    @Test func sendingANewMessageStartsAThreadInSent() async {
        let store = Fixture.store()
        let before = store.threads.count { $0.folder == .sent }
        let sent = await store.send(Draft(to: [SampleData.dan], subject: "Saturday", body: "I am in."))
        #expect(sent)
        #expect(store.threads.count { $0.folder == .sent } == before + 1)
    }

    @Test func arrowKeysWalkTheVisibleList() {
        let store = Fixture.store()
        store.selectNeighbor(offset: 1)
        #expect(store.selectedThreadID == "lease-renewal")
        store.selectNeighbor(offset: 1)
        #expect(store.selectedThreadID == "dental")
        store.selectNeighbor(offset: -5)
        #expect(store.selectedThreadID == "lease-renewal")
    }

    @Test func searchShowsLocalMatchesAtOnce() {
        let store = Fixture.store()
        store.searchQuery = "lease"
        store.search()
        #expect(store.searchResults.count == 6)
        #expect(store.isSearching)
        store.endSearch()
        #expect(store.searchResults.isEmpty)
        #expect(!store.isSearching)
    }
}

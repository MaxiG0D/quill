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

    @Test func labelsGoOnAndComeOff() {
        let store = Fixture.store()
        store.setLabel("travel", on: "dental", isOn: true)
        #expect(store.labels(for: store.thread("dental")!).map(\.id) == ["travel"])
        #expect(store.thread("dental")?.folder == .inbox)
        #expect(store.toast == nil)

        store.setLabel("travel", on: "dental", isOn: false)
        #expect(store.thread("dental")?.labelIDs == [])
    }

    @Test func movingToALabelLeavesTheInboxAndUndoRestoresIt() {
        let store = Fixture.store()
        let before = store.thread("dental")
        store.move("dental", toLabel: "travel")
        #expect(store.thread("dental")?.folder == .archive)
        #expect(store.thread("dental")?.labelIDs == ["travel"])
        #expect(store.toast?.title == "Moved to Travel")

        store.undo()
        #expect(store.thread("dental") == before)
    }

    @Test func movingFromOneLabelToAnotherSwapsThem() throws {
        let store = Fixture.store()
        store.show(.label("house"))
        let id = try #require(store.visibleThreads.first?.id)
        store.move(id, toLabel: "travel")
        #expect(store.thread(id)?.labelIDs == ["travel"])
        #expect(!store.visibleThreads.map(\.id).contains(id))
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

    @Test func unsnoozingReturnsThreadToInboxAndSupportsUndo() {
        let store = Fixture.store()
        store.snooze("hike", until: .tomorrow)
        #expect(!store.visibleThreads.map(\.id).contains("hike"))

        store.unsnooze("hike")
        #expect(store.visibleThreads.map(\.id).contains("hike"))
        #expect(store.thread("hike")?.snoozedUntil == nil)
        #expect(store.toast?.title == "Returned to Inbox")

        store.undo()
        #expect(!store.visibleThreads.map(\.id).contains("hike"))
        #expect(store.thread("hike")?.snoozedUntil != nil)
    }

    @Test func searchResultsReflectTriageAndTrashing() {
        let store = Fixture.store()
        store.searchQuery = "lease"
        store.search()
        let before = store.searchResults.count
        store.select("lease-renewal")
        #expect(store.searchResults.first { $0.id == "lease-renewal" }?.thread.isUnread == false)

        store.trash("lease-renewal")
        #expect(store.searchResults.count == before - 1)
        #expect(!store.searchResults.map(\.id).contains("lease-renewal"))

        store.undo()
        #expect(store.searchResults.count == before)
    }

    @Test func switchingMailboxResetsFilter() {
        let store = Fixture.store()
        store.filter = .unread
        store.show(.mailbox(.sent))
        #expect(store.filter == .all)
    }

    @Test func arrowKeysFollowVisualOrderWithPinsFirst() {
        let store = Fixture.store()
        store.togglePin("water")
        store.selectNeighbor(offset: 1)
        #expect(store.selectedThreadID == "lease-renewal")
        store.selectNeighbor(offset: 1)
        #expect(store.selectedThreadID == "water")
    }

    @Test func editingAndSendingDraftReplacesOriginalDraft() async throws {
        let store = Fixture.store()
        store.show(.mailbox(.drafts))
        let draftThread = try #require(store.visibleThreads.first)
        var draft = Draft.editing(draftThread)
        draft.to = [SampleData.priya]
        draft.body = "Updated message"

        let sent = await store.send(draft)
        #expect(sent)
        #expect(store.thread(draftThread.id) == nil)
    }

    @Test func repliedThreadsAppearInSentMailbox() async throws {
        let store = Fixture.store()
        let thread = try #require(store.thread("dental"))
        var reply = Draft.reply(to: thread, from: store.account)
        reply.body = "Confirmed!"
        #expect(await store.send(reply))
        store.show(.mailbox(.sent))
        #expect(store.visibleThreads.map(\.id).contains("dental"))
    }

    @Test func markAllReadEmptyTrashAndMarkAsSpamWithUndo() {
        let store = Fixture.store()
        #expect(store.unreadCount == 2)
        store.markAllRead()
        #expect(store.unreadCount == 0)

        store.markAsSpam("dental")
        #expect(store.thread("dental") == nil)
        store.undo()
        #expect(store.thread("dental") != nil)

        store.trash("dental")
        store.show(.mailbox(.trash))
        #expect(!store.visibleThreads.isEmpty)
        store.emptyTrash()
        #expect(store.visibleThreads.isEmpty)
    }

    @Test func inboxUnreadUsesGmailsWholeInboxTotal() {
        var snapshot = Fixture.snapshot
        snapshot.inboxUnread = 14_811
        let now = Fixture.now
        let store = MailStore(snapshot: snapshot, calendar: Fixture.calendar, clock: { now })
        #expect(store.inboxUnread == 14_811)
        #expect(store.unreadCount == 14_811)
        #expect(store.badge(for: .mailbox(.inbox)) == 14_811)

        let unread = store.threads.first { $0.isUnread && $0.belongs(to: .mailbox(.inbox), at: now) }
        store.markRead(unread!.id)
        #expect(store.inboxUnread == 14_810)
    }

    @Test func inboxUnreadFallsBackToLoadedThreadsWithoutATotal() {
        let store = Fixture.store()
        #expect(store.inboxUnread == 2)
    }

    @Test func returnedSnoozeBubblesToTodayAndClearsOnRead() {
        let oldDate = Fixture.date(daysAgo: 10, hour: 9)
        let wakeDate = Fixture.now.addingTimeInterval(-60)
        let thread = MailThread(
            id: "snoozed-old",
            subject: "Follow up",
            messages: [Message(sender: SampleData.priya, date: oldDate, body: "Checking in")],
            isUnread: true,
            snoozedUntil: wakeDate
        )
        let snapshot = MailSnapshot(account: SampleData.account, labels: [], threads: [thread])
        let store = MailStore(snapshot: snapshot, calendar: Fixture.calendar, clock: { Fixture.now })
        #expect(store.sections.first?.kind == .today)

        store.select("snoozed-old")
        #expect(store.thread("snoozed-old")?.isUnread == false)
        #expect(store.thread("snoozed-old")?.snoozedUntil == nil)
    }
}

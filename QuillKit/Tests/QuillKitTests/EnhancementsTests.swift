import Foundation
import Testing
@testable import QuillKit

@MainActor
struct EnhancementsTests {
    @Test func inlineCIDImagesAreInlinedOrExtracted() throws {
        let pngData = Data([0x89, 0x50, 0x4E, 0x47])
        let html = #"<p>Logo: <img src="cid:logo@example"></p><p>Hero: <img src="cid:hero@example"></p>"#
        let json = """
        {
          "mimeType": "multipart/related",
          "parts": [
            {
              "mimeType": "text/html",
              "body": { "size": \(html.utf8.count), "data": "\(GmailFixture.base64URL(html))" }
            },
            {
              "mimeType": "image/png",
              "headers": [{ "name": "Content-ID", "value": "<logo@example>" }],
              "body": { "size": \(pngData.count), "data": "\(pngData.base64URLEncoded)" }
            },
            {
              "mimeType": "image/jpeg",
              "headers": [{ "name": "Content-ID", "value": "<hero@example>" }],
              "body": { "size": 2048, "attachmentId": "att-hero" }
            }
          ]
        }
        """
        let part = try JSONDecoder().decode(GmailResource.Part.self, from: Data(json.utf8))
        let rendered = try #require(MessageContent.designedHTML(of: part))
        #expect(rendered.contains("data:image/png;base64,\(pngData.base64EncodedString())"))
        #expect(rendered.contains("cid:hero@example"))

        let deferred = MessageContent.inlineImages(of: part, messageID: "m-1")
        #expect(deferred.count == 1)
        #expect(deferred.first?.contentID == "hero@example")
        #expect(deferred.first?.attachmentID == "att-hero")
        #expect(deferred.first?.mimeType == "image/jpeg")
    }

    @Test func perMessageReplyReplyAllAndForwardTargetChosenMessage() throws {
        let store = Fixture.store()
        let thread = try #require(store.thread("lease-renewal"))
        let firstMessage = try #require(thread.messages.first)

        let reply = Draft.reply(to: firstMessage, in: thread, from: store.account, all: false)
        #expect(reply.threadID == thread.id)
        #expect(reply.to == [firstMessage.sender])
        #expect(reply.cc.isEmpty)
        #expect(reply.quoted == firstMessage.body)

        let replyAll = Draft.reply(to: firstMessage, in: thread, from: store.account, all: true)
        #expect(replyAll.to.contains(firstMessage.sender))
        #expect(!replyAll.cc.contains(store.account))

        let forward = Draft.forward(firstMessage, in: thread)
        #expect(forward.threadID == nil)
        #expect(forward.isForward)
        #expect(forward.subject.hasPrefix("Fwd:"))
        #expect(forward.quoted?.contains(firstMessage.body) == true)
    }

    @Test func multiSelectAndBulkTriageArchiveTrashReadAndStar() {
        let store = Fixture.store()
        store.toggleSelection("dental")
        store.toggleSelection("hike")
        #expect(store.selectedThreadIDs == ["dental", "hike"])

        store.setStarred(Array(store.selectedThreadIDs), isStarred: true)
        #expect(store.thread("dental")?.isStarred == true)
        #expect(store.thread("hike")?.isStarred == true)
        #expect(store.selectedThreadIDs.isEmpty)

        store.markUnread(["dental", "hike"], isUnread: false)
        #expect(store.thread("dental")?.isUnread == false)
        #expect(store.thread("hike")?.isUnread == false)

        store.trash(["dental", "hike"])
        #expect(store.thread("dental")?.folder == .trash)
        #expect(store.thread("hike")?.folder == .trash)
        #expect(store.toast?.title == "Deleted 2")

        store.undo()
        #expect(store.thread("dental")?.folder == .inbox)
        #expect(store.thread("hike")?.folder == .inbox)
    }

    @Test func selectRangeCoversVisualOrder() {
        let store = Fixture.store()
        store.select("lease-renewal")
        store.selectRange(to: "library")
        #expect(store.selectedThreadIDs.contains("lease-renewal"))
        #expect(store.selectedThreadIDs.contains("dental"))
        #expect(store.selectedThreadIDs.contains("library"))
    }

    @Test func undoSendCancelsDeliveryAndRestoresDraft() async {
        let store = Fixture.store()
        let before = store.threads.count
        let draft = Draft(to: [SampleData.dan], subject: "Hold on", body: "Wait a second")
        store.scheduleSend(draft, delay: .seconds(5))
        #expect(store.toast?.title == "Sending…")
        #expect(store.threads.count == before)

        store.undo()
        #expect(store.toast == nil)
        #expect(store.cancelledDraft == draft)
        #expect(store.threads.count == before)
    }

    @Test func searchFilterChipsAndRecentSearches() {
        let store = Fixture.store()

        store.recordSearch("lease")
        store.recordSearch("dental")
        store.recordSearch("LEASE")
        #expect(store.recentSearches == ["LEASE", "dental"])

        store.searchQuery = "lease"
        store.search()
        let allMatches = store.searchResults.count
        store.setSearchFilter(.attachments)
        #expect(store.searchResults.count <= allMatches)
        #expect(store.searchResults.allSatisfy { $0.thread.hasAttachments })

        store.clearRecentSearches()
        #expect(store.recentSearches.isEmpty)
    }

    @Test func labelCreateRenameAndDelete() async throws {
        let store = Fixture.store()
        await store.createLabel(named: "Receipts")
        let created = try #require(store.labels.first { $0.name == "Receipts" })

        store.setLabel(created.id, on: "dental", isOn: true)
        #expect(store.thread("dental")?.labelIDs.contains(created.id) == true)

        await store.renameLabel(created.id, to: "Taxes")
        #expect(store.label(created.id)?.name == "Taxes")

        store.show(.label(created.id))
        await store.deleteLabel(created.id)
        #expect(store.label(created.id) == nil)
        #expect(store.thread("dental")?.labelIDs.contains(created.id) == false)
        #expect(store.selection == .mailbox(.inbox))
    }

    @Test func customSnoozeDateHidesAndUndoesThread() {
        let store = Fixture.store()
        let targetDate = Fixture.now.addingTimeInterval(3 * 3600)
        store.snooze("hike", until: targetDate)
        #expect(store.thread("hike")?.snoozedUntil == targetDate)
        #expect(!store.visibleThreads.map(\.id).contains("hike"))

        store.undo()
        #expect(store.thread("hike")?.snoozedUntil == nil)
        #expect(store.visibleThreads.map(\.id).contains("hike"))
    }

    @Test func darkModeHTMLInjectsAdaptiveStyles() {
        let light = HTMLDocument.page(for: "<p>Newsletter</p>", darkAdapted: false)
        let dark = HTMLDocument.page(for: "<p>Newsletter</p>", darkAdapted: true)
        #expect(light.contains("light only"))
        #expect(!light.contains("invert(0.92)"))
        #expect(dark.contains("invert(0.92)"))
        #expect(dark.contains("img, video, picture, svg"))
    }

    @Test func printableHTMLIncludesSubjectAndMessages() throws {
        let store = Fixture.store()
        let thread = try #require(store.thread("lease-renewal"))
        let html = ThreadPrinter.shared.printableHTML(for: thread, timestamp: store.timestamp)
        #expect(html.contains(thread.subject))
        for message in thread.messages {
            #expect(html.contains(message.sender.displayName))
        }
    }

    @Test func preferencesAndAccountRegistryPersist() {
        let suiteName = "quill.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let prefs = MailPreferences(defaults: defaults)
        #expect(prefs.undoSendEnabled == true)
        #expect(prefs.darkModeHTML == false)
        #expect(prefs.activeSignature == nil)

        prefs.undoSendEnabled = false
        prefs.darkModeHTML = true
        prefs.signatureEnabled = true
        prefs.signature = "Best,\nMax"
        prefs.leadingSwipe = .star
        prefs.trailingSwipe = .delete

        let reloaded = MailPreferences(defaults: defaults)
        #expect(reloaded.undoSendEnabled == false)
        #expect(reloaded.darkModeHTML == true)
        #expect(reloaded.activeSignature == "Best,\nMax")
        #expect(reloaded.leadingSwipe == .star)
        #expect(reloaded.trailingSwipe == .delete)

        let registry = AccountRegistry(defaults: defaults)
        let first = AccountRecord(
            id: "max@example.com",
            name: "Max",
            email: "max@example.com",
            photoURL: nil,
            keychainAccount: "default",
            archiveFilename: "mailbox.json"
        )
        let second = AccountRecord(
            id: "work@example.com",
            name: "Work",
            email: "work@example.com",
            photoURL: nil,
            keychainAccount: AccountRegistry.keychainAccount(for: "work@example.com"),
            archiveFilename: AccountRegistry.archiveFilename(for: "work@example.com")
        )
        registry.upsert(first)
        registry.upsert(second)
        registry.activeID = second.id
        #expect(registry.accounts.count == 2)
        #expect(registry.activeID == "work@example.com")

        registry.remove(id: second.id)
        #expect(registry.accounts.map(\.id) == ["max@example.com"])
        #expect(registry.activeID == "max@example.com")
    }
}

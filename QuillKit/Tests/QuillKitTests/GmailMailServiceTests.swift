import Foundation
import Testing
@testable import QuillKit

struct GmailMailServiceTests {
    @Test func snapshotMapsGmailIntoQuillsMailbox() async throws {
        let http = await GmailFixture.mailbox()
        let snapshot = try await GmailFixture.service(http: http).snapshot()

        #expect(snapshot.account == GmailFixture.me)
        #expect(snapshot.labels.map(\.name) == ["House", "Travel"])
        #expect(snapshot.threads.map(\.id) == ["t1", "t2"])

        let lease = try #require(snapshot.threads.first)
        #expect(lease.subject == "Lease renewal")
        #expect(lease.folder == .inbox)
        #expect(lease.isUnread)
        #expect(lease.isStarred)
        #expect(lease.labelIDs == ["Label_1"])
        #expect(lease.messages.count == 2)

        let first = try #require(lease.messages.first)
        #expect(first.sender.name == "Priya Raman")
        #expect(first.sender.email == "priya@haldenleasing.example")
        #expect(first.to.map(\.displayName) == ["Max", "Okafor, Dan"])
        #expect(first.to.first == GmailFixture.me)
        #expect(first.body == "Hi Max,\n\nThe renewal is attached.\n\nPriya")
        #expect(first.attachments.map(\.filename) == ["Lease.pdf"])
        #expect(first.attachments.first?.byteCount == 48211)
        #expect(first.html == nil)
        #expect(first.preview == "The renewal is attached. Priya")

        let reply = try #require(lease.messages.last)
        #expect(reply.sender == GmailFixture.me)
        #expect(reply.body == "Thanks, signing tonight.")
        #expect(reply.quoted?.hasSuffix("The renewal is attached.") == true)

        let newsletter = try #require(snapshot.threads.last)
        #expect(newsletter.folder == .archive)
        #expect(newsletter.subject == "Café hours")
        #expect(newsletter.sender?.name == "Hollis Library — News")
        #expect(newsletter.messages.first?.body == "Fall hours & events\n\nOpen late on Thursdays.\nSee you soon — Hollis")
        #expect(newsletter.messages.first?.html?.hasPrefix("<html>") == true)
        #expect(newsletter.messages.first?.preview == "Fall hours & events. Don't miss Thursdays")
    }

    @Test func foldersFollowGmailsLabels() throws {
        let mapper = GmailMapper(account: GmailFixture.me, labels: [])
        func folder(_ labels: [[String]]) throws -> Mailbox? {
            let messages = labels.enumerated().map { index, labels in
                #"{"id":"m\#(index)","internalDate":"\#(index)","labelIds":[\#(labels.map { "\"\($0)\"" }.joined(separator: ","))]}"#
            }
            let json = #"{"id":"t","messages":[\#(messages.joined(separator: ","))]}"#
            let resource = try JSONDecoder().decode(GmailResource.Thread.self, from: Data(json.utf8))
            return mapper.thread(from: resource)?.thread.folder
        }
        #expect(try folder([["INBOX"], ["SENT"]]) == .inbox)
        #expect(try folder([["SENT"], ["SENT"]]) == .sent)
        #expect(try folder([[], ["SENT"]]) == .archive)
        #expect(try folder([["DRAFT"]]) == .drafts)
        #expect(try folder([["SENT"], ["DRAFT"]]) == .sent)
        #expect(try folder([["TRASH"], ["TRASH"]]) == .trash)
        #expect(try folder([["INBOX"], ["TRASH"]]) == .inbox)
        #expect(try folder([]) == nil)
    }

    @Test func aSecondRefreshFetchesOnlyWhatChanged() async throws {
        let http = await GmailFixture.mailbox()
        let service = GmailFixture.service(http: http)
        _ = try await service.snapshot()
        let before = await http.requests.count

        await http.reply(to: "/threads?", json: #"{"threads":[{"id":"t1","historyId":"101"},{"id":"t2","historyId":"200"}]}"#)
        let snapshot = try await service.snapshot()
        let everything = await http.log()
        let fetched = everything.dropFirst(before).filter { $0.contains("/threads/") }

        #expect(fetched == ["GET /gmail/v1/users/me/threads/t1"])
        #expect(snapshot.threads.count == 2)
    }

    @Test func olderInboxMailIsListedByName() async throws {
        // t2 sits in the Inbox but is too old to be among the newest threads.
        let http = await GmailFixture.mailbox()
        await http.reply(to: "/threads?", json: #"{"threads":[{"id":"t1","historyId":"100"}]}"#)
        await http.reply(to: "labelIds=INBOX", json: #"{"threads":[{"id":"t2","historyId":"200"},{"id":"t1","historyId":"100"}]}"#)
        let snapshot = try await GmailFixture.service(http: http).snapshot()
        #expect(snapshot.threads.map(\.id) == ["t2", "t1"])
        #expect(snapshot.isComplete)
    }

    @Test func aSpentAllowanceDeliversTheMailboxInPasses() async throws {
        let quota = #"{"error":{"code":403,"message":"Quota exceeded for quota metric 'Total Query Cost' and limit 'Units per minute per user' of service 'gmail.googleapis.com'.","errors":[{"domain":"usageLimits","reason":"rateLimitExceeded"}],"status":"PERMISSION_DENIED"}}"#
        let http = await GmailFixture.mailbox()
        await http.reply(to: "/threads/t2?", status: 403, json: quota)
        let service = GmailFixture.service(http: http)

        let first = try await service.snapshot()
        #expect(first.threads.map(\.id) == ["t1"])
        #expect(first.isComplete == false)

        // A minute later Gmail answers again, and only the missing thread is asked for.
        await http.reply(to: "/threads/t2?", json: GmailFixture.newsletterThread)
        let before = await http.requests.count
        let second = try await service.snapshot()
        let everything = await http.log()
        #expect(everything.dropFirst(before).filter { $0.contains("/threads/") } == ["GET /gmail/v1/users/me/threads/t2"])
        #expect(second.threads.map(\.id) == ["t1", "t2"])
        #expect(second.isComplete)
    }

    @Test func aSpentAllowanceWithNothingToShowIsReported() async throws {
        let quota = #"{"error":{"code":403,"message":"User Rate Limit Exceeded","errors":[{"domain":"usageLimits","reason":"userRateLimitExceeded"}]}}"#
        let http = await GmailFixture.mailbox()
        await http.reply(to: "/threads/t1?", status: 403, json: quota)
        await http.reply(to: "/threads/t2?", status: 403, json: quota)
        let service = GmailFixture.service(http: http)
        await #expect(throws: GmailError.rateLimited) {
            _ = try await service.snapshot()
        }
        // Each thread was asked for once: a spent allowance is not hammered.
        #expect(await http.log().filter { $0.contains("/threads/t") }.count <= 2)
    }

    @Test func theMailboxIsKeptOnTheDeviceBetweenLaunches() async throws {
        let file = MailArchiveFile(url: .temporaryDirectory.appending(path: "quill-\(UUID().uuidString).json"))
        defer { file.erase() }
        let http = await GmailFixture.mailbox()
        let first = GmailFixture.service(http: http, file: file)
        #expect(await first.cachedSnapshot() == nil)
        _ = try await first.snapshot()
        try await first.apply(.setPinned(true), to: ["t2"])

        let second = GmailFixture.service(http: StubHTTP(), file: file)
        let cached = try #require(await second.cachedSnapshot())
        #expect(cached.threads.map(\.id) == ["t1", "t2"])
        #expect(cached.threads.last?.isPinned == true)

        await second.erase()
        #expect(await second.cachedSnapshot() == nil)
        #expect(file.load() == nil)
    }

    @Test func anArchiveInAnOlderFormatIsFetchedAgain() async throws {
        let file = MailArchiveFile(url: .temporaryDirectory.appending(path: "quill-\(UUID().uuidString).json"))
        defer { file.erase() }
        let http = await GmailFixture.mailbox()
        _ = try await GmailFixture.service(http: http, file: file).snapshot()

        var old = try #require(file.load())
        old.format = nil
        old.threads[1].messages[0].html = nil
        try file.save(old)
        let before = await http.requests.count

        let service = GmailFixture.service(http: http, file: file)
        #expect(await service.cachedSnapshot()?.threads.count == 2)
        let snapshot = try await service.snapshot()
        let fetched = await http.log().dropFirst(before).filter { $0.contains("/threads/t") }
        #expect(fetched.count == 2)
        #expect(snapshot.threads.last?.messages.first?.html != nil)
        #expect(file.load()?.format == MailArchive.currentFormat)
    }

    @Test func changesAreCarriedToGmail() async throws {
        let http = await GmailFixture.mailbox()
        await http.reply(to: "/modify", json: "{}")
        await http.reply(to: "/trash", json: "{}")
        await http.reply(to: "/untrash", json: "{}")
        let service = GmailFixture.service(http: http)
        _ = try await service.snapshot()
        let before = await http.requests.count

        try await service.apply(.move(.archive), to: ["t1"])
        try await service.apply(.setStarred(true), to: ["t1"])
        try await service.apply(.setUnread(false), to: ["t1"])
        try await service.apply(.move(.trash), to: ["t1"])
        try await service.apply(.move(.inbox), to: ["t1"])
        try await service.apply(.snooze(.now), to: ["t1"])

        let everything = await http.log()
        let log = Array(everything.dropFirst(before))
        #expect(log == [
            "POST /gmail/v1/users/me/threads/t1/modify",
            "POST /gmail/v1/users/me/messages/m2/modify",
            "POST /gmail/v1/users/me/threads/t1/modify",
            "POST /gmail/v1/users/me/threads/t1/trash",
            "POST /gmail/v1/users/me/threads/t1/untrash",
            "POST /gmail/v1/users/me/threads/t1/modify",
        ])
        #expect(await http.labelChange(at: before) == ["addLabelIds": [], "removeLabelIds": ["INBOX"]])
        #expect(await http.labelChange(at: before + 1) == ["addLabelIds": ["STARRED"], "removeLabelIds": []])
        #expect(await http.labelChange(at: before + 2) == ["addLabelIds": [], "removeLabelIds": ["UNREAD"]])
        #expect(await http.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer access")
    }

    @Test func aReplyIsSentIntoItsThread() async throws {
        let http = await GmailFixture.mailbox()
        await http.reply(to: "/messages/send", json: #"{"id":"m9"}"#)
        let service = GmailFixture.service(http: http)
        _ = try await service.snapshot()

        let draft = Draft(to: [Contact(name: "Priya Raman", email: "priya@haldenleasing.example")], subject: "Re: Lease renewal", body: "Done.", threadID: "t1")
        try await service.send(draft)

        let sent = try #require(await http.requests.last?.httpBody)
        let message = try JSONDecoder().decode([String: String].self, from: sent)
        #expect(message["threadId"] == "t1")
        let raw = String(decoding: try #require(Data(base64URLEncoded: message["raw"] ?? "")), as: UTF8.self)
        #expect(raw.contains("In-Reply-To: <two@mail.example>"))
        #expect(raw.contains("From: \"Max\" <max@example.com>"))

        let withFile = Draft(to: draft.to, subject: "Photos", attachments: [Attachment(filename: "a.jpg")])
        await #expect(throws: GmailError.attachmentsUnsupported) {
            try await service.send(withFile)
        }
    }

    @Test func gmailsErrorsReachThePersonInItsWords() async throws {
        let http = await GmailFixture.mailbox()
        await http.reply(to: "/labels", status: 403, json: #"{"error":{"code":403,"message":"Gmail API has not been enabled.","status":"PERMISSION_DENIED"}}"#)
        let service = GmailFixture.service(http: http)
        await #expect(throws: GmailError.status(403, "Gmail API has not been enabled.")) {
            _ = try await service.snapshot()
        }
    }

    @Test func aSpentAllowanceFallsBackToTheKeptMailbox() async throws {
        let quota = #"{"error":{"code":429,"message":"Too many requests"}}"#
        let http = await GmailFixture.mailbox()
        let service = GmailFixture.service(http: http)
        _ = try await service.snapshot()

        // Even listing the mailbox is refused.
        await http.reply(to: "/threads?", status: 429, json: quota)
        let kept = try await service.snapshot()
        #expect(kept.threads.map(\.id) == ["t1", "t2"])
        #expect(kept.isComplete == false)
    }

    @MainActor
    @Test func aSpentAllowanceNeverReachesThePerson() async throws {
        let quota = #"{"error":{"code":403,"message":"User Rate Limit Exceeded","errors":[{"domain":"usageLimits","reason":"userRateLimitExceeded"}]}}"#
        let http = await GmailFixture.mailbox()
        await http.reply(to: "/threads/t1?", status: 403, json: quota)
        await http.reply(to: "/threads/t2?", status: 403, json: quota)
        let store = MailStore(service: GmailFixture.service(http: http), retryDelay: .milliseconds(20))

        await store.load()
        #expect(store.phase == .loading)
        #expect(store.alert == nil)

        // Gmail answers again, and the mailbox arrives without anyone asking.
        await http.reply(to: "/threads/t1?", json: GmailFixture.leaseThread)
        await http.reply(to: "/threads/t2?", json: GmailFixture.newsletterThread)
        for _ in 0..<200 where store.phase != .loaded {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(store.phase == .loaded)
        #expect(store.threads.count == 2)
        #expect(store.alert == nil)
    }

    @MainActor
    @Test func theStoreShowsTheKeptMailboxBeforeTheFreshOne() async throws {
        let file = MailArchiveFile(url: .temporaryDirectory.appending(path: "quill-\(UUID().uuidString).json"))
        defer { file.erase() }
        _ = try await GmailFixture.service(http: await GmailFixture.mailbox(), file: file).snapshot()

        // Offline: nothing answers, yet the mailbox opens from the device.
        let offline = GmailFixture.service(http: StubHTTP(), file: file)
        let store = MailStore(service: offline)
        await store.load()
        #expect(store.phase == .loaded)
        #expect(store.threads.count == 2)
        #expect(store.account == GmailFixture.me)
        #expect(store.alert != nil)
    }
}

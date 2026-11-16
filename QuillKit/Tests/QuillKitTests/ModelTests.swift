import Foundation
import Testing
@testable import QuillKit

struct ModelTests {
    @Test(arguments: [
        ("Priya Raman", "PR"),
        ("Max", "M"),
        ("Hollis Public Library", "HP"),
        ("", "SE")
    ])
    func initialsTakeOneLetterFromEachOfTheFirstTwoWords(name: String, expected: String) {
        #expect(Contact(name: name, email: "someone@example.com").initials == expected)
    }

    @Test func stableToneDoesNotChangeBetweenCalls() {
        #expect(LabelTone.stable(for: "a@example.com") == LabelTone.stable(for: "a@example.com"))
    }

    @Test(arguments: [
        ("Lease.pdf", AttachmentKind.pdf),
        ("Lake.JPG", .image),
        ("Notes.docx", .document),
        ("archive.zip", .file),
        ("README", .file)
    ])
    func attachmentKindFollowsTheExtension(filename: String, kind: AttachmentKind) {
        #expect(Attachment(filename: filename).kind == kind)
    }

    @Test func snoozedThreadsLeaveTheInboxUntilTheirDatePasses() {
        var thread = MailThread(subject: "Later", messages: [])
        thread.snoozedUntil = Fixture.now.addingTimeInterval(3600)
        #expect(!thread.belongs(to: .mailbox(.inbox), at: Fixture.now))
        #expect(thread.belongs(to: .mailbox(.snoozed), at: Fixture.now))

        let later = Fixture.now.addingTimeInterval(7200)
        #expect(thread.belongs(to: .mailbox(.inbox), at: later))
        #expect(thread.hasReturned(at: later))
    }

    @Test func trashedThreadsLeaveStarredAndLabels() {
        let thread = MailThread(subject: "Gone", messages: [], labelIDs: ["house"], folder: .trash, isStarred: true)
        #expect(!thread.belongs(to: .mailbox(.starred), at: Fixture.now))
        #expect(!thread.belongs(to: .label("house"), at: Fixture.now))
        #expect(thread.belongs(to: .mailbox(.trash), at: Fixture.now))
    }

    @Test func replyAnswersTheLatestSenderAndKeepsTheSubjectPrefixSingle() throws {
        let thread = try #require(Fixture.snapshot.threads.first { $0.id == "lease-renewal" })
        let reply = Draft.reply(to: thread, from: SampleData.account)
        #expect(reply.to == [SampleData.priya])
        #expect(reply.cc.isEmpty)
        #expect(reply.subject == "Re: Lease renewal for the apartment")
        #expect(reply.threadID == thread.id)

        let again = Draft.reply(to: MailThread(subject: reply.subject, messages: thread.messages), from: SampleData.account)
        #expect(again.subject == reply.subject)
    }

    @Test func replyAllKeepsEveryoneButTheAccount() throws {
        let thread = try #require(Fixture.snapshot.threads.first { $0.id == "lease-renewal" })
        let reply = Draft.reply(to: thread, from: SampleData.account, all: true)
        #expect(reply.cc == [SampleData.haldenLeasing])
    }

    @Test func forwardCarriesAttachments() throws {
        let thread = try #require(Fixture.snapshot.threads.first { $0.id == "lease-renewal" })
        let forward = Draft.forward(thread)
        #expect(forward.subject.hasPrefix("Fwd: "))
        #expect(forward.attachments.map(\.filename) == ["Lease_Renewal_2027.pdf"])
        #expect(forward.to.isEmpty)
    }

    @Test func expansionStartsWithOnlyTheNewestMessageOpen() throws {
        let thread = try #require(Fixture.snapshot.threads.first { $0.id == "lease-renewal" })
        var expansion = MessageExpansion(thread: thread)
        #expect(thread.messages.map(expansion.contains) == [false, false, true])

        expansion.toggle(thread.messages[0])
        expansion.toggle(thread.messages[2])
        #expect(thread.messages.map(expansion.contains) == [true, false, false])
    }
}

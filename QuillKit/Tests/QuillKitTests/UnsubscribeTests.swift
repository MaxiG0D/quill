import Foundation
import Testing
@testable import QuillKit

struct UnsubscribeTests {
    @Test func oneClickNeedsHTTPSAndThePostHeader() throws {
        let offer = try #require(Unsubscribe(
            list: "<mailto:leave@list.example?subject=Remove%20me>,\r\n <https://list.example/u?id=7>",
            post: "List-Unsubscribe=One-Click"
        ))
        #expect(offer.oneClick == URL(string: "https://list.example/u?id=7"))
        #expect(offer.page == URL(string: "https://list.example/u?id=7"))
        #expect(offer.mail == Unsubscribe.Mail(address: "leave@list.example", subject: "Remove me", body: nil))

        let pageOnly = try #require(Unsubscribe(list: "<https://list.example/u>", post: nil))
        #expect(pageOnly.oneClick == nil)
        #expect(pageOnly.page != nil)

        let plainHTTP = try #require(Unsubscribe(list: "<http://list.example/u>", post: "List-Unsubscribe=One-Click"))
        #expect(plainHTTP.oneClick == nil)
    }

    @Test func headersWithNothingUsableOfferNothing() {
        #expect(Unsubscribe(list: nil, post: nil) == nil)
        #expect(Unsubscribe(list: "not a link", post: nil) == nil)
        #expect(Unsubscribe(list: "<ftp://list.example/u>", post: nil) == nil)
    }

    @Test func theMapperReadsTheHeadersButNotOnMailFromTheAccount() throws {
        let mapper = GmailMapper(account: GmailFixture.me, labels: [])
        func thread(from sender: String) throws -> MailThread {
            let json = """
                {"id":"t","messages":[{"id":"m","labelIds":["INBOX"],"internalDate":"1","payload":{"mimeType":"text/plain","headers":[
                  {"name":"From","value":"\(sender)"},
                  {"name":"List-Unsubscribe","value":"<https://list.example/u>"},
                  {"name":"List-Unsubscribe-Post","value":"List-Unsubscribe=One-Click"}
                ]}}]}
                """
            let resource = try JSONDecoder().decode(GmailResource.Thread.self, from: Data(json.utf8))
            return try #require(mapper.thread(from: resource)?.thread)
        }
        #expect(try thread(from: "News <news@list.example>").messages.first?.unsubscribe?.oneClick != nil)
        #expect(try thread(from: "max@example.com").messages.first?.unsubscribe == nil)
    }

    @Test func oneClickPostsWithoutTheAccountsToken() async throws {
        let http = StubHTTP()
        await http.reply(to: "list.example/u", json: "")
        let api = GmailAPI(auth: GoogleAuth(client: GmailFixture.client, http: http, tokens: MemoryTokenStore()), http: http)
        try await api.postOneClickUnsubscribe(to: try #require(URL(string: "https://list.example/u")))
        let request = try #require(await http.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(await http.body(at: 0) == "List-Unsubscribe=One-Click")
    }

    @Test func aFailedOneClickFallsBackToMailThenThePage() async throws {
        let service = UnsubscribingService(oneClickFails: true)
        let both = try #require(Unsubscribe(list: "<mailto:leave@list.example>, <https://list.example/u>", post: "List-Unsubscribe=One-Click"))
        #expect(try await service.unsubscribe(both) == .done)
        #expect(await service.sent.first?.to.first?.email == "leave@list.example")

        let page = try #require(Unsubscribe(list: "<https://list.example/u>", post: "List-Unsubscribe=One-Click"))
        #expect(try await service.unsubscribe(page) == .openPage(try #require(URL(string: "https://list.example/u"))))
    }
}

@MainActor
struct UnsubscribeStoreTests {
    @Test func unsubscribingRemembersTheSenderAndFindsTheirInboxMail() async throws {
        let store = Fixture.store()
        let message = try #require(store.thread("library")?.messages.first)
        #expect(!store.isUnsubscribed(from: message.sender))
        #expect(await store.unsubscribe(from: message) { _ in })
        #expect(store.isUnsubscribed(from: message.sender))
        #expect(store.inboxThreads(from: message.sender) == ["library"])
    }

    @Test func archivingSeveralThreadsUndoesTogether() {
        let store = Fixture.store()
        store.archive(["dental", "library"])
        #expect(store.toast?.title == "Archived 2")
        #expect(store.thread("library")?.folder == .archive)
        store.undo()
        #expect(store.thread("dental")?.folder == .inbox)
        #expect(store.thread("library")?.folder == .inbox)
    }
}

/// Sends nothing, and fails one-click unsubscribes when asked to.
private actor UnsubscribingService: MailService {
    let oneClickFails: Bool
    private(set) var sent: [Draft] = []

    init(oneClickFails: Bool) {
        self.oneClickFails = oneClickFails
    }

    func snapshot() async throws -> MailSnapshot { Fixture.snapshot }
    func apply(_ change: ThreadChange, to ids: [MailThread.ID]) async throws {}
    func send(_ draft: Draft) async throws { sent.append(draft) }
    func search(_ query: String) async throws -> [MailThread] { [] }

    func postOneClickUnsubscribe(to url: URL) async throws {
        if oneClickFails { throw GmailError.status(500, "") }
    }
}

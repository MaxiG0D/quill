import Foundation
import Testing
@testable import QuillKit

struct SenderPictureTests {
    @Test func aLogoBelongsToTheSiteBehindTheSendingAddress() {
        #expect(SenderLogo.domain(for: "news@email.example.com") == "example.com")
        #expect(SenderLogo.domain(for: "Hello@Example.com") == "example.com")
        #expect(SenderLogo.domain(for: "info@mail.shop.co.uk") == "shop.co.uk")
        #expect(SenderLogo.domain(for: "info@ville.montreal.qc.ca") == "montreal.qc.ca")
        #expect(SenderLogo.domain(for: "no-reply@accounts.google.com") == "google.com")
        #expect(SenderLogo.url(for: "example.com")?.absoluteString == "https://www.google.com/s2/favicons?domain=example.com&sz=128")
    }

    @Test func peopleAtMailProvidersGetNoLogo() {
        #expect(SenderLogo.domain(for: "priya@gmail.com") == nil)
        #expect(SenderLogo.domain(for: "sam@yahoo.co.uk") == nil)
        #expect(SenderLogo.domain(for: "lea@videotron.ca") == nil)
        #expect(SenderLogo.domain(for: "ana@me.com") == nil)
        #expect(SenderLogo.domain(for: "billing@bell.ca") == "bell.ca")
        #expect(SenderLogo.domain(for: "not an address") == nil)
        #expect(SenderLogo.domain(for: "someone@localhost") == nil)
    }

    @Test func contactPicturesAreReadByAddressAndLetterTilesAreLeftOut() async {
        let http = StubHTTP()
        await http.reply(to: "/otherContacts", json: """
            {"otherContacts":[
              {"emailAddresses":[{"value":"Priya@Example.com"}],"photos":[{"url":"https://lh3.googleusercontent.com/a/priya=s100"}]},
              {"emailAddresses":[{"value":"sam@example.com"}],"photos":[{"url":"https://lh3.googleusercontent.com/a/letter=s100","default":true}]},
              {"emailAddresses":[{"value":"lea@example.com"}],"photos":[{"url":"https://lh3.googleusercontent.com/a/gathered=s100"}]}
            ]}
            """)
        await http.reply(to: "/people/me/connections", json: """
            {"connections":[
              {"emailAddresses":[{"value":"lea@example.com"},{"value":"lea@work.example"}],"photos":[{"url":"https://lh3.googleusercontent.com/a/saved=s100"}]},
              {"photos":[{"url":"https://lh3.googleusercontent.com/a/nobody=s100"}]}
            ]}
            """)
        let auth = GoogleAuth(client: GmailFixture.client, http: http, tokens: MemoryTokenStore(GmailFixture.token()))
        let photos = await GmailAPI(auth: auth, http: http).contactPhotos()

        #expect(photos.count == 3)
        #expect(photos["priya@example.com"]?.absoluteString == "https://lh3.googleusercontent.com/a/priya=s192-c")
        #expect(photos["lea@example.com"]?.absoluteString == "https://lh3.googleusercontent.com/a/saved=s192-c")
        #expect(photos["lea@work.example"]?.absoluteString == "https://lh3.googleusercontent.com/a/saved=s192-c")
    }

    @Test func noContactsPermissionMeansNoPicturesAndNoFailure() async {
        let http = StubHTTP()
        await http.reply(to: "people.googleapis.com", status: 403, json: #"{"error":{"message":"Request had insufficient authentication scopes."}}"#)
        let auth = GoogleAuth(client: GmailFixture.client, http: http, tokens: MemoryTokenStore(GmailFixture.token()))
        #expect(await GmailAPI(auth: auth, http: http).contactPhotos().isEmpty)
    }

    @Test func signInAsksToSeeContacts() throws {
        let auth = GoogleAuth(client: GmailFixture.client, http: StubHTTP(), tokens: MemoryTokenStore())
        let url = try #require(auth.authorizationURL(challenge: "abc", state: "xyz"))
        let scope = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "scope" }?.value ?? ""
        #expect(scope.contains("contacts.readonly"))
        #expect(scope.contains("contacts.other.readonly"))
    }
}

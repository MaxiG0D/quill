import Foundation
import Testing
@testable import QuillKit

struct GoogleAuthTests {
    @Test func clientDerivesItsRedirectFromTheClientID() {
        let client = GmailFixture.client
        #expect(client.redirectScheme == "com.googleusercontent.apps.1234-abcd")
        #expect(client.redirectURI == "com.googleusercontent.apps.1234-abcd:/oauth2redirect")
        #expect(GoogleClient(id: "") == nil)
        #expect(GoogleClient(id: "not-a-client-id") == nil)
    }

    @Test func challengeMatchesTheExampleInTheStandard() {
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        #expect(PKCE().verifier.count >= 43)
        #expect(PKCE().verifier != PKCE().verifier)
    }

    @Test func authorizationPageAsksForMailAndCarriesTheChallenge() throws {
        let auth = GoogleAuth(client: GmailFixture.client, http: StubHTTP(), tokens: MemoryTokenStore())
        let url = try #require(auth.authorizationURL(challenge: "abc", state: "xyz"))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        #expect(url.host() == "accounts.google.com")
        #expect(value("client_id") == GmailFixture.client.id)
        #expect(value("code_challenge") == "abc")
        #expect(value("code_challenge_method") == "S256")
        #expect(value("state") == "xyz")
        #expect(value("scope")?.contains("gmail.modify") == true)
    }

    @Test func signingInTradesTheCodeForATokenAndKeepsIt() async throws {
        let http = StubHTTP()
        await http.reply(to: "/token", json: #"{"access_token":"a1","refresh_token":"r1","expires_in":3599}"#)
        let tokens = MemoryTokenStore()
        let auth = GoogleAuth(client: GmailFixture.client, http: http, tokens: tokens)
        #expect(await auth.isSignedIn() == false)

        let callback = try #require(URL(string: "com.googleusercontent.apps.1234-abcd:/oauth2redirect?state=s1&code=c%2F1"))
        try await auth.signIn(callback: callback, verifier: "v1", state: "s1")

        #expect(await auth.isSignedIn())
        #expect(try await auth.accessToken() == "a1")
        #expect(await tokens.token?.refreshToken == "r1")
        let body = await http.body(at: 0)
        #expect(body.contains("code=c%2F1"))
        #expect(body.contains("code_verifier=v1"))
        #expect(body.contains("grant_type=authorization_code"))
    }

    @Test func signingInRejectsAReplyMeantForAnotherRequest() async throws {
        let auth = GoogleAuth(client: GmailFixture.client, http: StubHTTP(), tokens: MemoryTokenStore())
        let wrongState = try #require(URL(string: "x:/oauth2redirect?state=other&code=c1"))
        await #expect(throws: GoogleAuthError.invalidCallback) {
            try await auth.signIn(callback: wrongState, verifier: "v1", state: "s1")
        }
        let refused = try #require(URL(string: "x:/oauth2redirect?error=access_denied"))
        await #expect(throws: GoogleAuthError.denied("access_denied")) {
            try await auth.signIn(callback: refused, verifier: "v1", state: "s1")
        }
    }

    @Test func signingInWithoutGmailAccessIsRefused() async throws {
        let http = StubHTTP()
        await http.reply(to: "/token", json: #"{"access_token":"a1","refresh_token":"r1","expires_in":3599,"scope":"openid https://www.googleapis.com/auth/userinfo.email"}"#)
        let tokens = MemoryTokenStore()
        let auth = GoogleAuth(client: GmailFixture.client, http: http, tokens: tokens)
        let callback = try #require(URL(string: "x:/oauth2redirect?state=s1&code=c1"))
        await #expect(throws: GoogleAuthError.mailNotAllowed) {
            try await auth.signIn(callback: callback, verifier: "v1", state: "s1")
        }
        #expect(await auth.isSignedIn() == false)
    }

    @Test func anExpiredTokenIsRefreshedOnce() async throws {
        let http = StubHTTP()
        await http.reply(to: "/token", json: #"{"access_token":"a2","expires_in":3599}"#)
        let tokens = MemoryTokenStore(GmailFixture.token(expiresIn: -10))
        let auth = GoogleAuth(client: GmailFixture.client, http: http, tokens: tokens)

        #expect(try await auth.accessToken() == "a2")
        #expect(try await auth.accessToken() == "a2")
        #expect(await http.requests.count == 1)
        #expect(await http.body(at: 0).contains("refresh_token=refresh"))
        // Google keeps the refresh token when it sends no new one.
        #expect(await tokens.token?.refreshToken == "refresh")
    }

    @Test func aWithdrawnSignInClearsTheTokenAndSaysSo() async throws {
        let http = StubHTTP()
        await http.reply(to: "/token", status: 400, json: #"{"error":"invalid_grant"}"#)
        let tokens = MemoryTokenStore(GmailFixture.token(expiresIn: -10))
        let auth = GoogleAuth(client: GmailFixture.client, http: http, tokens: tokens)
        let wasTold = Flag()
        await auth.onSignedOut { await wasTold.raise() }

        await #expect(throws: GoogleAuthError.signedOut) {
            _ = try await auth.accessToken()
        }
        #expect(await tokens.token == nil)
        #expect(await wasTold.isRaised)
        #expect(await auth.isSignedIn() == false)
    }
}

actor Flag {
    private(set) var isRaised = false
    func raise() { isRaised = true }
}

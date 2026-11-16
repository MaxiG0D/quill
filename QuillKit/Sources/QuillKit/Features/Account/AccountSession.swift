import AuthenticationServices
import Observation
import SwiftUI

/// Who is signed in, and the mailbox that goes with them.
///
/// With a Google client ID the session signs in to Gmail. Without one, or when a
/// screenshot asks for a fixed screen, it opens the sample mailbox and never asks.
@MainActor
@Observable
final class AccountSession {
    enum Phase: Equatable {
        /// Checking the keychain for an earlier sign-in.
        case launching
        case signedOut
        case ready
    }

    private(set) var phase: Phase
    /// The signed-in account's mailbox, or the sample one.
    private(set) var store: MailStore? = nil
    private(set) var isSigningIn = false
    /// A sign-in failure the person should hear about.
    var alert: String?

    private let auth: GoogleAuth?
    private let http: any HTTPClient
    private var service: GmailMailService? = nil

    init(
        options: LaunchOptions = LaunchOptions(),
        googleClientID: String = "",
        http: any HTTPClient = URLSessionHTTPClient(),
        tokens: any TokenStore = KeychainTokenStore()
    ) {
        self.http = http
        if options.screen == nil, let client = GoogleClient(id: googleClientID) {
            auth = GoogleAuth(client: client, http: http, tokens: tokens)
            phase = .launching
        } else {
            auth = nil
            store = options.makeStore()
            phase = .ready
        }
    }

    /// True when there is a real account to sign out of.
    var canSignOut: Bool {
        auth != nil && phase == .ready
    }

    /// Picks up an earlier sign-in at launch.
    func restore() async {
        guard let auth, phase == .launching else { return }
        await auth.onSignedOut { [weak self] in
            await self?.close()
        }
        if await auth.isSignedIn() {
            open(with: auth)
        } else {
            phase = .signedOut
        }
    }

    func signIn(using web: WebAuthenticationSession) async {
        guard let auth, !isSigningIn else { return }
        let pkce = PKCE()
        let state = UUID().uuidString
        guard let url = auth.authorizationURL(challenge: pkce.challenge, state: state) else { return }

        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let callback = try await web.authenticate(using: url, callbackURLScheme: auth.client.redirectScheme)
            try await auth.signIn(callback: callback, verifier: pkce.verifier, state: state)
            open(with: auth)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // Closing the sign-in page is a choice, not a failure.
        } catch {
            alert = error.localizedDescription
        }
    }

    func signOut() async {
        guard let auth else { return }
        await auth.signOut()
        await close()
    }

    private func open(with auth: GoogleAuth) {
        let service = GmailMailService(api: GmailAPI(auth: auth, http: http))
        self.service = service
        store = MailStore(service: service)
        phase = .ready
    }

    /// Returns to the sign-in screen and removes the account's mail from the device.
    private func close() async {
        await service?.erase()
        await MessageWebView.forget()
        service = nil
        store = nil
        phase = .signedOut
    }
}

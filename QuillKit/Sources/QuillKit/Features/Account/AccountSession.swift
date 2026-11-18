import AuthenticationServices
import Observation
import os
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
    private let relayAddress: String
    /// The push relay, when this build has one and someone is signed in.
    private var relay: PushRelay?
    private var service: GmailMailService? = nil
    private static let log = Logger(subsystem: "com.maxig0d.quill", category: "push")
    /// New-mail notifications, for a real account only.
    let notifier: MailNotifier?
    /// Senders' pictures, for a real account only.
    let pictures: SenderPictures
    private var restoration: Task<Void, Never>?
    private var polling: Task<Void, Never>?
    /// How often Quill looks for new mail while it is running.
    private static let pollInterval = Duration.seconds(60)
    /// How many polls pass between registrations with the push relay.
    private static let pollsPerRegistration = 15

    init(
        options: LaunchOptions = LaunchOptions(),
        googleClientID: String = "",
        pushRelayURL: String = "",
        http: any HTTPClient = URLSessionHTTPClient(),
        tokens: any TokenStore = KeychainTokenStore(),
        notifier: MailNotifier? = nil
    ) {
        self.http = http
        relayAddress = pushRelayURL
        if options.screen == nil, let client = GoogleClient(id: googleClientID) {
            auth = GoogleAuth(client: client, http: http, tokens: tokens)
            self.notifier = notifier ?? MailNotifier()
            pictures = SenderPictures(http: http)
            phase = .launching
        } else {
            auth = nil
            self.notifier = nil
            pictures = SenderPictures()
            store = options.makeStore()
            phase = .ready
        }
    }

    /// True when there is a real account to sign out of.
    var canSignOut: Bool {
        auth != nil && phase == .ready
    }

    /// Picks up an earlier sign-in at launch. Callers that arrive together share one attempt.
    func restore() async {
        if restoration == nil {
            restoration = Task { await resume() }
        }
        await restoration?.value
    }

    /// Looks for new mail when the system wakes Quill in the background.
    func checkMail(arrived threadID: String? = nil) async {
        await restore()
        // The announced thread first, on its own, so it is there before the full refresh ends.
        if let threadID {
            await store?.bringIn(arrived: [threadID])
        }
        await store?.refreshUnseen()
    }

    private func resume() async {
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
        // While the token still works, so the relay can tell who is asking.
        await stopPush()
        await auth.signOut()
        await close()
    }

    private func open(with auth: GoogleAuth) {
        let api = GmailAPI(auth: auth, http: http)
        let service = GmailMailService(api: api)
        self.service = service
        pictures.load(from: api)
        let store = MailStore(service: service, notifier: notifier)
        self.store = store
        phase = .ready
        relay = PushRelay(address: relayAddress, auth: auth, http: http)
        notifier?.onSwitch = { [weak self] isOn in
            if isOn {
                await self?.startPush()
            } else {
                await self?.stopPush()
            }
        }
        PushDevice.shared.onPush = { [weak self] threadID in
            await self?.checkMail(arrived: threadID)
        }
        PushDevice.shared.onActivityToken = { [weak self] in
            await self?.startPush()
        }
        Task {
            await startPush()
        }
        polling?.cancel()
        polling = Task { [weak self, weak store] in
            var polls = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard !Task.isCancelled, let store else { return }
                await store.refreshUnseen()
                polls += 1
                // A relay that could not be reached at launch gets another chance, and one
                // that has since lost this device gets it back.
                if self?.notifier?.isPushed == false || polls.isMultiple(of: Self.pollsPerRegistration) {
                    await self?.startPush()
                }
            }
        }
    }

    /// Hands this device to the push relay, on every launch so the relay's record stays
    /// current. Until that has worked, Quill announces new mail itself.
    private func startPush() async {
        guard let relay, notifier?.isEnabled == true, let token = await PushDevice.shared.token() else { return }
        do {
            try await relay.register(token, activityStartToken: PushDevice.shared.activityStartToken)
            notifier?.setPushed(true)
        } catch {
            Self.log.info("Push relay did not take this device: \(String(describing: error), privacy: .public)")
            notifier?.setPushed(false)
        }
    }

    /// Has the push relay send this account's devices a made-up sign-in code.
    func sendTestCode() async -> Bool {
        guard let relay else { return false }
        return (try? await relay.sendTestCode()) != nil
    }

    private func stopPush() async {
        notifier?.setPushed(false)
        guard let relay, let token = PushDevice.shared.knownToken else { return }
        try? await relay.unregister(token)
    }

    /// Returns to the sign-in screen and removes the account's mail from the device.
    private func close() async {
        polling?.cancel()
        polling = nil
        relay = nil
        await notifier?.reset()
        await service?.erase()
        pictures.forget()
        MessagePreloader.shared.forget()
        await MessageWebView.forget()
        service = nil
        store = nil
        phase = .signedOut
    }
}

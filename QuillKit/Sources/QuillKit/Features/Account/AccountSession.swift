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
    /// All signed-in Google accounts on this device.
    private(set) var accounts: [AccountRecord] = []
    private(set) var activeAccountID: String?
    /// A sign-in failure the person should hear about.
    var alert: String?

    private let googleClient: GoogleClient?
    private var auth: GoogleAuth?
    private let defaultTokens: any TokenStore
    private let registry = AccountRegistry()
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
        self.defaultTokens = tokens
        relayAddress = pushRelayURL
        if options.screen == nil, let client = GoogleClient(id: googleClientID) {
            googleClient = client
            auth = GoogleAuth(client: client, http: http, tokens: tokens)
            self.notifier = notifier ?? MailNotifier()
            pictures = SenderPictures(http: http)
            phase = .launching
        } else {
            googleClient = nil
            auth = nil
            self.notifier = nil
            pictures = SenderPictures()
            store = options.makeStore()
            phase = .ready
        }
    }

    /// True when there is a real account to sign out of.
    var canSignOut: Bool {
        googleClient != nil && phase == .ready
    }

    /// Keeps the active account's display name and picture in step once the mailbox loads.
    func syncActiveProfile(_ contact: Contact) {
        guard googleClient != nil, !contact.email.isEmpty else { return }
        let email = contact.email.lowercased()
        let existing = registry.accounts.first { $0.id == activeAccountID || $0.id == email }
        let record = AccountRecord(
            id: email,
            name: contact.name,
            email: email,
            photoURL: contact.photoURL,
            keychainAccount: existing?.keychainAccount ?? "default",
            archiveFilename: existing?.archiveFilename ?? "mailbox.json"
        )
        registry.upsert(record)
        registry.activeID = record.id
        accounts = registry.accounts
        activeAccountID = record.id
    }

    /// Picks up an earlier sign-in at launch. Callers that arrive together share one attempt.
    func restore() async {
        if restoration == nil {
            restoration = Task { await resume() }
        }
        await restoration?.value
    }

    /// Archives or deletes a thread from an alert's button. Quill may have just been launched
    /// in the background for it, so the account opens first.
    func file(_ threadID: MailThread.ID, in mailbox: Mailbox) async {
        await restore()
        await store?.fileFromNotification(threadID, in: mailbox)
    }

    /// Looks for new or changed mail when the system wakes Quill in the background.
    func checkMail(arrived threadIDs: [String] = []) async {
        await restore()
        // Announced or changed threads first, on their own, so they update before the full refresh ends.
        if !threadIDs.isEmpty {
            await store?.bringIn(arrived: threadIDs)
        }
        await store?.refreshUnseen()
    }

    private func resume() async {
        guard let client = googleClient, phase == .launching else { return }
        accounts = registry.accounts
        let chosen = accounts.first { $0.id == registry.activeID } ?? accounts.first
        if let chosen {
            let accountAuth = makeAuth(client: client, keychainAccount: chosen.keychainAccount)
            if await accountAuth.isSignedIn() {
                activeAccountID = chosen.id
                await openAccount(auth: accountAuth, archiveFilename: chosen.archiveFilename)
                return
            }
        }
        // Fallback / seamless migration for a legacy single-account sign-in in the default keychain slot.
        let legacyAuth = auth ?? GoogleAuth(client: client, http: http, tokens: defaultTokens)
        if await legacyAuth.isSignedIn() {
            activeAccountID = "default"
            await openAccount(auth: legacyAuth, archiveFilename: "mailbox.json")
        } else {
            phase = .signedOut
        }
    }

    func signIn(using web: WebAuthenticationSession) async {
        await authenticateAccount(using: web, isAdditional: false)
    }

    /// Signs in an additional Google account and switches to it immediately.
    func addAccount(using web: WebAuthenticationSession) async {
        await authenticateAccount(using: web, isAdditional: true)
    }

    private func authenticateAccount(using web: WebAuthenticationSession, isAdditional: Bool) async {
        guard let client = googleClient, !isSigningIn else { return }
        let pkce = PKCE()
        let state = UUID().uuidString
        let stagingStore = MemoryAuthStore()
        let stagingAuth = GoogleAuth(client: client, http: http, tokens: stagingStore)
        guard let url = stagingAuth.authorizationURL(challenge: pkce.challenge, state: state, selectAccount: isAdditional) else { return }

        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let callback = try await web.authenticate(using: url, callbackURLScheme: client.redirectScheme)
            try await stagingAuth.signIn(callback: callback, verifier: pkce.verifier, state: state)
            guard let token = try await stagingStore.load() else { return }

            let userInfo = try? await GmailAPI(auth: stagingAuth, http: http).userInfo()
            let email = userInfo?.email.lowercased() ?? ""
            let isFirst = registry.accounts.isEmpty && !isAdditional
            let existing = registry.accounts.first { $0.email == email }
            let keychainAccount = existing?.keychainAccount ?? AccountRegistry.keychainAccount(for: email, isPrimary: isFirst)
            let archiveFilename = existing?.archiveFilename ?? AccountRegistry.archiveFilename(for: email, isPrimary: isFirst)

            let targetTokens: any TokenStore = keychainAccount == "default"
                ? defaultTokens
                : KeychainTokenStore(account: keychainAccount)
            try await targetTokens.save(token)

            let recordID = email.isEmpty ? "default" : email
            let record = AccountRecord(
                id: recordID,
                name: userInfo?.name ?? "",
                email: email,
                photoURL: userInfo?.photoURL,
                keychainAccount: keychainAccount,
                archiveFilename: archiveFilename
            )
            registry.upsert(record)
            registry.activeID = record.id
            accounts = registry.accounts
            activeAccountID = record.id

            if isAdditional {
                await tearDownActiveSession(eraseArchive: false)
            }
            let accountAuth = makeAuth(client: client, keychainAccount: keychainAccount)
            await openAccount(auth: accountAuth, archiveFilename: archiveFilename)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // Closing the sign-in page is a choice, not a failure.
        } catch {
            alert = error.localizedDescription
        }
    }

    /// Switches to another already signed-in Google account.
    func switchAccount(to id: String) async {
        guard let client = googleClient,
              id != activeAccountID,
              let record = registry.accounts.first(where: { $0.id == id }) else { return }
        await tearDownActiveSession(eraseArchive: false)
        registry.activeID = record.id
        activeAccountID = record.id
        accounts = registry.accounts
        let accountAuth = makeAuth(client: client, keychainAccount: record.keychainAccount)
        await openAccount(auth: accountAuth, archiveFilename: record.archiveFilename)
    }

    func signOut(accountID: String? = nil) async {
        let targetID = accountID ?? activeAccountID
        guard let client = googleClient else { return }

        if let targetID, let record = registry.accounts.first(where: { $0.id == targetID }), targetID != activeAccountID {
            let otherAuth = makeAuth(client: client, keychainAccount: record.keychainAccount)
            await otherAuth.signOut()
            MailArchiveFile.named(record.archiveFilename).erase()
            registry.remove(id: targetID)
            accounts = registry.accounts
            return
        }

        // Signing out the currently active account.
        await stopPush()
        await auth?.signOut()
        if let targetID {
            registry.remove(id: targetID)
        }
        accounts = registry.accounts

        if let next = accounts.first {
            await tearDownActiveSession(eraseArchive: true)
            registry.activeID = next.id
            activeAccountID = next.id
            let nextAuth = makeAuth(client: client, keychainAccount: next.keychainAccount)
            await openAccount(auth: nextAuth, archiveFilename: next.archiveFilename)
        } else {
            await close()
        }
    }

    private func makeAuth(client: GoogleClient, keychainAccount: String) -> GoogleAuth {
        let tokenStore: any TokenStore = keychainAccount == "default"
            ? defaultTokens
            : KeychainTokenStore(account: keychainAccount)
        return GoogleAuth(client: client, http: http, tokens: tokenStore)
    }

    private func openAccount(auth: GoogleAuth, archiveFilename: String) async {
        self.auth = auth
        await auth.onSignedOut { [weak self] in
            await self?.close(reason: "Your Google sign-in expired. Please sign in again.")
        }
        open(with: auth, archiveFile: MailArchiveFile.named(archiveFilename))
    }

    private func open(with auth: GoogleAuth, archiveFile: MailArchiveFile = .standard) {
        let api = GmailAPI(auth: auth, http: http)
        let service = GmailMailService(api: api, file: archiveFile)
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
        PushDevice.shared.onPush = { [weak self] threadIDs in
            await self?.checkMail(arrived: threadIDs)
        }
        PushDevice.shared.onActivityToken = { [weak self] in
            await self?.startPush()
        }
        PushDevice.shared.onActivityRegistered = { [weak self] activityToken, code in
            guard let relay = self?.relay, let token = await PushDevice.shared.token() else { return }
            try? await relay.registerActivity(deviceToken: token, activityToken: activityToken, code: code)
        }
        PushDevice.shared.onCodeCopied = { [weak self] code in
            try? await self?.relay?.dismissCode(code)
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
            try await relay.register(
                token,
                activityStartToken: LiveActivitySetting.isOn ? PushDevice.shared.activityStartToken : nil,
                allInbox: !MailPreferences.storedInboxTabs
            )
            notifier?.setPushed(true)
        } catch {
            Self.log.info("Push relay did not take this device: \(String(describing: error), privacy: .public)")
            notifier?.setPushed(false)
        }
    }

    /// The Live Activity switch changed: end any activity that is up when it is off, and
    /// tell the relay whether it may start one.
    func liveActivityChanged() async {
        if !LiveActivitySetting.isOn {
            await LiveActivitySetting.onTurnedOff?()
        }
        await startPush()
    }

    /// The Inbox Tabs switch changed: recount the Inbox badge, and tell the relay how this
    /// device counts it.
    func inboxTabsChanged() async {
        await store?.refresh(isQuiet: true)
        await startPush()
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

    private func tearDownActiveSession(eraseArchive: Bool) async {
        polling?.cancel()
        polling = nil
        relay = nil
        if eraseArchive {
            store?.clearAccountDefaults()
            await notifier?.reset()
            await service?.erase()
        }
        pictures.forget()
        MessagePreloader.shared.forget()
        await MessageWebView.forget()
        service = nil
        store = nil
    }

    /// Returns to the sign-in screen and removes the account's mail from the device.
    private func close(reason: String? = nil) async {
        await tearDownActiveSession(eraseArchive: true)
        activeAccountID = nil
        phase = .signedOut
        if let reason {
            alert = reason
        }
    }
}

/// Ephemeral token holder used while discovering a newly signed-in account's email address.
private actor MemoryAuthStore: TokenStore {
    private var token: OAuthToken?
    func load() async throws -> OAuthToken? { token }
    func save(_ token: OAuthToken) async throws { self.token = token }
    func clear() async throws { token = nil }
}

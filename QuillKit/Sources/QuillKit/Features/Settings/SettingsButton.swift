import AuthenticationServices
import SwiftUI

/// The account's picture, which opens Settings: a sheet on iOS, the Settings window on macOS.
/// Long-pressing or right-clicking offers quick account switching when multiple accounts are signed in.
struct SettingsButton: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(AccountSession.self) private var session: AccountSession?
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

    var size = MonogramAvatar.Size.compact
    var showsName = false
    @State private var isHovering = false

    var body: some View {
        Button(action: show) {
            if showsName {
                HStack(spacing: Spacing.s) {
                    avatar
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.account.displayName)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Palette.label)
                            .lineLimit(1)
                        if !store.account.name.isEmpty, !store.account.email.isEmpty {
                            Text(store.account.email)
                                .textRole(.meta)
                                .foregroundStyle(Palette.secondaryLabel)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .background(isHovering ? Palette.fill : .clear, in: .rect(cornerRadius: Radius.small))
                .contentShape(.rect)
            } else {
                avatar
            }
        }
        .buttonStyle(.pressable)
        .onHover { isHovering = $0 }
        .contextMenu {
            if let session, session.canSignOut {
                ForEach(session.accounts) { record in
                    Button {
                        Task {
                            router.reset()
                            await session.switchAccount(to: record.id)
                        }
                    } label: {
                        if record.id == session.activeAccountID {
                            Label(record.email, systemImage: "checkmark")
                        } else {
                            Text(record.email)
                        }
                    }
                }
                if !session.accounts.isEmpty {
                    Divider()
                }
                Button("Add Account…", systemImage: "person.badge.plus") {
                    Task {
                        router.reset()
                        await session.addAccount(using: webAuthenticationSession)
                    }
                }
                Divider()
            }
            Button("Settings…", systemImage: "gearshape", action: show)
        }
        .help("Settings")
        .accessibilityLabel("Settings")
        #if os(macOS)
        .task {
            // A screenshot launch asks for Settings before there is a window to open it from.
            if router.isShowingSettings { show() }
        }
        #endif
    }

    private var avatar: some View {
        MonogramAvatar(store.account, size: size)
            .clipShape(.circle)
            .overlay {
                Circle().strokeBorder(Palette.separator, lineWidth: 1)
            }
            .shadow(color: .black.opacity(size == .compact ? 0 : 0.06), radius: 12, y: 4)
            .contentShape(.circle)
    }

    private func show() {
        #if os(macOS)
        router.isShowingSettings = false
        openSettings()
        #else
        router.isShowingSettings = true
        #endif
    }
}

extension View {
    /// Presents Settings over this view on iOS. macOS shows Settings in its own window.
    @ViewBuilder
    func settingsSheet(isPresented: Binding<Bool>) -> some View {
        #if os(iOS)
        self.sheet(isPresented: isPresented) {
            SettingsView()
        }
        #else
        self
        #endif
    }
}

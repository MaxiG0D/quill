import SwiftUI

/// Quill's settings: a sheet on iOS and the Settings window on macOS.
struct SettingsView: View {
    @Environment(AccountSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(macOS)
        ScrollView {
            sections
                .padding(Spacing.xl)
        }
        .frame(width: 460)
        .frame(minHeight: 360, maxHeight: 640)
        .background(Palette.background)
        #else
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    Text("Settings")
                        .font(.system(.title, design: .serif, weight: .semibold))
                        .foregroundStyle(Palette.label)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    SheetCloseButton(action: close)
                }
                .padding(.top, Spacing.xl)
                sections
            }
            .padding(.horizontal, Spacing.m)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    private var preferences: MailPreferences { .shared }

    private var sections: some View {
        @Bindable var preferences = preferences
        return VStack(alignment: .leading, spacing: Spacing.s) {
            if session.canSignOut, let account = session.store?.account {
                heading(session.accounts.count > 1 ? "Accounts" : "Account")
                AccountRow(account: account)
                    .card()
                    .padding(.bottom, Spacing.s)
            }
            if session.canSignOut, let notifier = session.notifier {
                heading("Notifications")
                VStack(alignment: .leading, spacing: Spacing.m) {
                    NotificationSwitch(notifier: notifier)
                    #if os(iOS)
                    LiveActivitySwitch()
                    #endif
                    #if DEBUG
                    TestCodeButton()
                    #endif
                }
                .card()
                .padding(.bottom, Spacing.s)
            }
            heading("Reading & Compose")
            VStack(alignment: .leading, spacing: Spacing.m) {
                #if os(macOS)
                DefaultMailSwitch()
                Divider().overlay(Palette.separator)
                #endif
                Toggle(isOn: $preferences.inboxTabs) {
                    Text("Inbox Tabs")
                        .font(.body)
                        .foregroundStyle(Palette.label)
                }
                .onChange(of: preferences.inboxTabs) {
                    Task { await session.inboxTabsChanged() }
                }
                Divider().overlay(Palette.separator)
                Toggle(isOn: $preferences.undoSendEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Undo Send")
                            .font(.body)
                            .foregroundStyle(Palette.label)
                        Text("Hold outgoing mail for 5 seconds so you can cancel it.")
                            .textRole(.meta)
                            .foregroundStyle(Palette.secondaryLabel)
                    }
                }
                Divider().overlay(Palette.separator)
                Toggle(isOn: $preferences.darkModeHTML) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dark Mode for HTML Emails")
                            .font(.body)
                            .foregroundStyle(Palette.label)
                        Text("Adapt light-background newsletters when Dark Mode is active.")
                            .textRole(.meta)
                            .foregroundStyle(Palette.secondaryLabel)
                    }
                }
                Divider().overlay(Palette.separator)
                MapsAppPicker()
                Divider().overlay(Palette.separator)
                SignatureSettingsCard(preferences: preferences)
            }
            .card()
            .padding(.bottom, Spacing.s)
            #if os(iOS)
            heading("Swipe Actions")
            SwipeActionsSettingsCard(preferences: preferences)
                .card()
                .padding(.bottom, Spacing.s)
            #endif
            heading("App Icon")
            AppIconPicker()
                .card()
        }
    }

    private func heading(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .textRole(.section)
            .foregroundStyle(Palette.label)
            .padding(.leading, Spacing.xxs)
            .accessibilityAddTraits(.isHeader)
    }

    private func close() {
        dismiss()
    }
}

private extension View {
    /// The white rounded panel a settings group sits on.
    func card() -> some View {
        padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface)
            .clipShape(.rect(cornerRadius: Radius.large))
    }
}

#Preview {
    SettingsView()
        .environment(AccountSession())
}

import SwiftUI

/// Quill's settings: a sheet on iOS and the Settings window on macOS.
struct SettingsView: View {
    @Environment(AccountSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(macOS)
        sections
            .padding(Spacing.xl)
            .frame(width: 460)
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

    private var sections: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if session.canSignOut, let account = session.store?.account {
                heading("Account")
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

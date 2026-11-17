import SwiftUI

/// The compact layout's mailbox switcher: mailboxes and labels in two cards,
/// with Settings behind the gear.
struct MailboxesSheet: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(spacing: Spacing.s) {
                    MonogramAvatar(store.account)
                    Text("Mailboxes")
                        .font(.system(.title, design: .serif, weight: .semibold))
                        .foregroundStyle(Palette.label)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    SettingsButton()
                    SheetCloseButton(action: close)
                }
                .padding(.top, Spacing.s)

                VStack(spacing: 0) {
                    MailboxRows(isCard: true, onSelect: close)
                }
                .background(Palette.surface)
                .clipShape(.rect(cornerRadius: Radius.large))

                Text("Labels")
                    .textRole(.section)
                    .foregroundStyle(Palette.label)
                    .padding(.top, Spacing.xs)
                    .padding(.leading, Spacing.xxs)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 0) {
                    LabelRows(isCard: true, onSelect: close)
                }
                .background(Palette.surface)
                .clipShape(.rect(cornerRadius: Radius.large))
            }
            .padding(.horizontal, Spacing.m)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.background)
        .settingsSheet(isPresented: $router.isShowingSettings)
    }

    private func close() {
        router.isShowingMailboxes = false
    }
}

#Preview {
    MailboxesSheet()
        .environment(MailStore(snapshot: SampleData.snapshot(now: .now)))
        .environment(Router())
}

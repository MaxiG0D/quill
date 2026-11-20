import SwiftUI

/// The first column of the wide layout and the phone's drawer: Compose on the Mac, then
/// mailboxes and labels, and the account on the Mac.
struct SidebarView: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    /// Runs after a mailbox or label is chosen, so a drawer can close.
    var onSelect: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                // iPad keeps Compose floating over the list, within the thumb's reach.
                #if os(macOS)
                // Laid out as a sidebar row, so it lines up with the mailboxes below it.
                Button(action: compose) {
                    HStack(spacing: Spacing.s) {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text("Compose Email")
                            .font(.title3.weight(.medium))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Palette.warm)
                    .padding(.horizontal, Spacing.s)
                    .frame(minHeight: Metrics.target + 8)
                    .background(Palette.warm.opacity(0.12), in: .rect(cornerRadius: Radius.small))
                    .contentShape(.rect)
                }
                .buttonStyle(.pressable)
                .padding(.bottom, Spacing.xs)
                #endif
                MailboxRows(onSelect: onSelect)
                Text("Labels")
                    .textRole(.section)
                    .foregroundStyle(Palette.label)
                    .padding(.leading, Spacing.s)
                    .padding(.top, Spacing.l)
                    .padding(.bottom, Spacing.xxs)
                    .accessibilityAddTraits(.isHeader)
                LabelRows(onSelect: onSelect)
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
        }
        #if os(macOS)
        // The account's picture holds the sidebar's bottom-left corner and opens Settings.
        .safeAreaBar(edge: .bottom, spacing: 0) {
            SettingsButton()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.xs)
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        #else
        // On iOS the picture floats in the screen's bottom-left corner, over this list.
        .contentMargins(.bottom, Metrics.listBottomPadding, for: .scrollContent)
        #endif
        .navigationTitle("")
    }

    private func compose() {
        router.draft = Draft()
    }
}

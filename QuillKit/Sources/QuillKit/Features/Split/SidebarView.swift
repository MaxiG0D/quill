import SwiftUI

/// The first column of the wide layout and the phone's drawer: Compose on the Mac, then
/// mailboxes, labels and the account.
struct SidebarView: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    /// Runs after a mailbox or label is chosen, so a drawer can close.
    var onSelect: () -> Void = {}

    @State private var bottomInset = 0.0

    /// How far the account row sinks into a home indicator's inset, which is taller
    /// than the indicator itself. Insets without an indicator are left alone.
    private static func lift(_ inset: Double) -> Double {
        min(Spacing.s, max(0, inset - Spacing.l))
    }

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
        // The account rides on the sidebar's own surface; the labels soften away beneath it.
        .safeAreaBar(edge: .bottom, spacing: 0) {
            HStack(spacing: Spacing.s) {
                MonogramAvatar(store.account, size: .small)
                Text(store.account.displayName)
                    .font(.body)
                    .foregroundStyle(Palette.label)
                Spacer()
                SettingsButton()
            }
            .padding(.leading, Spacing.m)
            .padding(.trailing, Spacing.xs)
            .padding(.top, Spacing.xxs)
            .padding(.bottom, bottomInset > 0 ? -Self.lift(bottomInset) : Spacing.xs)
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .onGeometryChange(for: Double.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
        .navigationTitle("")
    }

    private func compose() {
        router.draft = Draft()
    }
}

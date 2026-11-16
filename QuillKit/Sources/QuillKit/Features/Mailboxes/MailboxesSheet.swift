import SwiftUI

/// The compact layout's mailbox switcher: mailboxes and labels in two cards.
struct MailboxesSheet: View {
    @Environment(MailStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(spacing: Spacing.s) {
                    MonogramAvatar(store.account)
                    Text("Mailboxes")
                        .font(.system(.title, design: .serif, weight: .semibold))
                        .foregroundStyle(Palette.label)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(action: close) {
                        Label("Close", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Palette.secondaryLabel)
                            .frame(width: 32, height: 32)
                            .background(Palette.fill, in: .circle)
                            .frame(minWidth: Metrics.target, minHeight: Metrics.target, alignment: .trailing)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.pressable)
                }
                .padding(.top, Spacing.xl)

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
        .presentationDragIndicator(.visible)
    }

    private func close() {
        dismiss()
    }
}

#Preview {
    MailboxesSheet()
        .environment(MailStore(snapshot: SampleData.snapshot(now: .now)))
}

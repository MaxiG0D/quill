import SwiftUI

/// The first column of the wide layout and the phone's drawer: Compose on the Mac, then
/// mailboxes and labels, and the account on the Mac.
struct SidebarView: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    /// Runs after a mailbox or label is chosen, so a drawer can close.
    var onSelect: () -> Void = {}
    /// True when the iOS floating account button overlaps the bottom of this sidebar.
    var hasFloatingAccount = true

    @State private var isCreatingLabel = false

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
                .help("New Message (⌘N)")
                .padding(.bottom, Spacing.xs)
                #endif
                MailboxRows(onSelect: onSelect)
                HStack(alignment: .firstTextBaseline) {
                    Text("Labels")
                        .textRole(.section)
                        .foregroundStyle(Palette.label)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button {
                        isCreatingLabel = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.secondaryLabel)
                            .frame(width: 28, height: 28)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.pressable)
                    .help("New Label")
                    .accessibilityLabel("New Label")
                }
                .padding(.leading, Spacing.s)
                .padding(.trailing, Spacing.xxs)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xxs)
                LabelRows(onSelect: onSelect)
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
        }
        .sheet(isPresented: $isCreatingLabel) {
            LabelEditorSheet(title: "New Label", confirmTitle: "Create") { name in
                await store.createLabel(named: name)
            }
        }
        #if os(macOS)
        // The account's picture holds the sidebar's bottom-left corner and opens Settings.
        .safeAreaBar(edge: .bottom, spacing: 0) {
            SettingsButton(showsName: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs)
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        #else
        // On iOS the picture floats in the screen's bottom-left corner, over the split sidebar.
        .contentMargins(.bottom, hasFloatingAccount ? Metrics.listBottomPadding : Spacing.m, for: .scrollContent)
        #endif
        .navigationTitle("")
    }

    private func compose() {
        if router.draft == nil {
            router.draft = Draft()
        }
    }
}

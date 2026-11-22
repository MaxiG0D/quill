import SwiftUI

/// Lets the user pick which actions are triggered by leading and trailing row swipes.
struct SwipeActionsSettingsCard: View {
    @Bindable var preferences: MailPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            pickerRow("Swipe Right", selection: $preferences.leadingSwipe)
            Divider().overlay(Palette.separator)
            pickerRow("Swipe Right (Secondary)", selection: $preferences.leadingSecondarySwipe)
            Divider().overlay(Palette.separator)
            pickerRow("Swipe Left", selection: $preferences.trailingSwipe)
            Divider().overlay(Palette.separator)
            pickerRow("Swipe Left (Secondary)", selection: $preferences.trailingSecondarySwipe)
        }
    }

    private func pickerRow(_ title: String, selection: Binding<SwipeAction>) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(Palette.label)
            Spacer(minLength: Spacing.s)
            Picker(title, selection: selection) {
                ForEach(SwipeAction.allCases) { action in
                    Label(action.title, systemImage: action.symbol)
                        .tag(action)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }
}

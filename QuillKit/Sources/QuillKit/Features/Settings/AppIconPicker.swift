import SwiftUI

/// A row of Quill's icons. Tapping one makes it the app's icon.
struct AppIconPicker: View {
    @AppStorage(AppIcon.storageKey) private var selection = AppIcon.primary

    var body: some View {
        HStack(spacing: Spacing.s) {
            ForEach(AppIcon.allCases) { icon in
                Button {
                    choose(icon)
                } label: {
                    AppIconTile(icon: icon, isSelected: icon == selection)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(icon.title)
                .accessibilityAddTraits(icon == selection ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func choose(_ icon: AppIcon) {
        let previous = selection
        guard icon != previous else { return }
        selection = icon
        Task {
            do {
                try await icon.apply()
            } catch {
                // The system refused the change, so the ring goes back to the icon in use.
                selection = previous
            }
        }
    }
}

#Preview {
    AppIconPicker()
        .padding()
}

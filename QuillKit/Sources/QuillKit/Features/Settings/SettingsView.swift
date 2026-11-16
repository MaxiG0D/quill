import SwiftUI

/// Quill's settings: a sheet on iOS and the Settings window on macOS.
struct SettingsView: View {
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
            Text("App Icon")
                .textRole(.section)
                .foregroundStyle(Palette.label)
                .padding(.leading, Spacing.xxs)
                .accessibilityAddTraits(.isHeader)
            AppIconPicker()
                .padding(Spacing.m)
                .background(Palette.surface)
                .clipShape(.rect(cornerRadius: Radius.large))
        }
    }

    private func close() {
        dismiss()
    }
}

#Preview {
    SettingsView()
}

import SwiftUI

/// Sheet to create a new Gmail label or rename an existing one.
struct LabelEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let confirmTitle: String
    let onSave: @MainActor (String) async -> Void

    @State private var name: String
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    init(title: String, initialName: String = "", confirmTitle: String = "Save", onSave: @escaping @MainActor (String) async -> Void) {
        self.title = title
        self.confirmTitle = confirmTitle
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text(title)
                    .textRole(.title)
                    .foregroundStyle(Palette.label)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                SheetCloseButton(action: { dismiss() })
            }

            TextField("Label name", text: $name)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(Spacing.s)
                .background(Palette.fill, in: .rect(cornerRadius: Radius.small))
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(save)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button(confirmTitle, action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accentFill)
                    .disabled(trimmedName.isEmpty || isSaving)
            }
        }
        .padding(Spacing.l)
        .background(Palette.surface)
        .task { isFocused = true }
        #if os(macOS)
        .frame(width: 340)
        #else
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
        #endif
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let value = trimmedName
        guard !value.isEmpty, !isSaving else { return }
        isSaving = true
        Task {
            await onSave(value)
            isSaving = false
            dismiss()
        }
    }
}

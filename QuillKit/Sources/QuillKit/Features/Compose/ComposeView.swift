import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The message composer, presented as a sheet.
struct ComposeView: View {
    @Environment(MailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontResolutionContext) private var fontContext

    private let original: Draft

    @State private var draft: Draft
    @State private var text: AttributedString
    @State private var selection = AttributedTextSelection()
    @State private var photo: PhotosPickerItem?
    @State private var isSending = false
    @State private var isConfirmingCancel = false
    @State private var isImportingFile = false
    @FocusState private var isBodyFocused: Bool

    init(draft: Draft) {
        original = draft
        _draft = State(initialValue: draft)
        _text = State(initialValue: AttributedString(draft.body))
    }

    var body: some View {
        VStack(spacing: 0) {
            ComposeHeader(
                title: draft.threadID == nil ? "New Message" : "Reply",
                canSend: draft.canSend,
                isSending: isSending,
                onCancel: cancel,
                onSend: send
            )
            .confirmationDialog("Draft", isPresented: $isConfirmingCancel) {
                Button("Delete Draft", role: .destructive, action: discard)
                Button("Save Draft", action: save)
            }

            VStack(alignment: .leading, spacing: 0) {
                RecipientField(title: "To", recipients: $draft.to)
                Divider().overlay(Palette.separator)
                RecipientField(title: "Cc", recipients: $draft.cc)
                Divider().overlay(Palette.separator)
                TextField("Subject", text: $draft.subject, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(Palette.label)
                    .lineLimit(1...3)
                    .submitLabel(.next)
                    .padding(.vertical, Spacing.m)
                Divider().overlay(Palette.separator)
            }
            .padding(.horizontal, Spacing.l)

            TextEditor(text: $text, selection: $selection)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(Palette.label)
                .scrollContentBackground(.hidden)
                .focused($isBodyFocused)
                .padding(.horizontal, Spacing.m)
                .padding(.top, Spacing.xs)
                .frame(minHeight: 120)
                .accessibilityLabel("Message")

            if !draft.attachments.isEmpty {
                VStack(spacing: Spacing.xs) {
                    ForEach(draft.attachments) { attachment in
                        AttachmentRow(attachment: attachment) {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                remove(attachment)
                            }
                        }
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.s)
            }
        }
        .tint(Palette.accent)
        .background(Palette.surface)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FormatBar(
                photo: $photo,
                onStyle: apply,
                onBold: toggleBold,
                onItalic: toggleItalic,
                onList: insertListItem,
                onAttach: importFile
            )
        }
        .animation(Motion.list, value: draft.attachments)
        .interactiveDismissDisabled(isDirty)
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.item], allowsMultipleSelection: true, onCompletion: attach)
        .onChange(of: photo) {
            attachPhoto()
        }
        .onChange(of: text) {
            draft.body = String(text.characters)
        }
        .task {
            isBodyFocused = !draft.to.isEmpty
        }
    }

    private var isDirty: Bool {
        draft != original && !draft.isEmpty
    }

    // MARK: Sending and closing

    private func send() {
        isSending = true
        Task {
            if await store.send(draft) {
                dismiss()
            }
            isSending = false
        }
    }

    private func cancel() {
        if isDirty {
            isConfirmingCancel = true
        } else {
            dismiss()
        }
    }

    private func discard() {
        dismiss()
    }

    private func save() {
        store.saveDraft(draft)
        dismiss()
    }

    // MARK: Formatting

    private func toggleBold() {
        text.transformAttributes(in: &selection) { container in
            let font = container.font ?? .default
            let resolved = font.resolve(in: fontContext)
            container.font = font.bold(!resolved.isBold)
        }
    }

    private func toggleItalic() {
        text.transformAttributes(in: &selection) { container in
            let font = container.font ?? .default
            let resolved = font.resolve(in: fontContext)
            container.font = font.italic(!resolved.isItalic)
        }
    }

    private func apply(_ style: ComposeTextStyle) {
        text.transformAttributes(in: &selection) { container in
            container.font = style.font
        }
    }

    private func insertListItem() {
        text.replaceSelection(&selection, withCharacters: "\n• ")
    }

    // MARK: Attachments

    private func importFile() {
        isImportingFile = true
    }

    private func attach(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                draft.attachments.append(Attachment(filename: url.lastPathComponent, byteCount: size))
            }
        case .failure(let error):
            store.alert = error.localizedDescription
        }
    }

    private func attachPhoto() {
        guard photo != nil else { return }
        let count = draft.attachments.count { $0.kind == .image }
        draft.attachments.append(Attachment(filename: count == 0 ? "Photo.jpg" : "Photo \(count + 1).jpg"))
        photo = nil
    }

    private func remove(_ attachment: Attachment) {
        draft.attachments.removeAll { $0.id == attachment.id }
    }
}

#Preview {
    ComposeView(draft: Draft(to: [SampleData.priya], subject: "Re: Lease renewal"))
        .environment(MailStore(snapshot: SampleData.snapshot(now: .now)))
}

import SwiftUI

/// A short notice above the search bar that lets the last triage action be reversed.
struct UndoToastView: View {
    @Environment(MailStore.self) private var store

    let toast: UndoToast

    var body: some View {
        HStack(spacing: Spacing.s) {
            Label(toast.title, systemImage: toast.symbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.background)
            Spacer(minLength: Spacing.m)
            Button("Undo", action: undo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.background)
                .frame(minHeight: Metrics.target)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.l)
        .background(Palette.label, in: .capsule)
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        .frame(maxWidth: 420)
        .task(id: toast.id) {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.list) {
                store.dismissToast(toast.id)
            }
        }
    }

    private func undo() {
        withAnimation(Motion.list) {
            store.undo()
        }
    }
}

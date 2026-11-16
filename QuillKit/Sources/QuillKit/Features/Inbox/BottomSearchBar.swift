import SwiftUI

/// The bar at the foot of the compact layout while a search is under way:
/// the search field beside Close.
struct BottomSearchBar: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    var isFocused: FocusState<Bool>.Binding

    private let height = 54.0

    var body: some View {
        @Bindable var store = store
        HStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Palette.secondaryLabel)
                    .accessibilityHidden(true)
                TextField("Search", text: $store.searchQuery)
                    .focused(isFocused)
                    .submitLabel(.search)
                    .plainTextEntry()
                    .tint(Palette.accent)
                if !store.searchQuery.isEmpty {
                    IconButton("Clear", systemImage: "xmark.circle.fill", width: 32, action: clear)
                        .foregroundStyle(Palette.secondaryLabel)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .font(.body)
            .padding(.horizontal, Spacing.l)
            .frame(height: height)
            .background(Palette.surface, in: .capsule)
            .overlay {
                Capsule().strokeBorder(Palette.separator, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

            Button(action: close) {
                Label("Close Search", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.label)
                    .frame(width: height, height: height)
                    .background(Palette.surface, in: .circle)
                    .overlay {
                        Circle().strokeBorder(Palette.separator, lineWidth: 1)
                    }
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs)
        .animation(Motion.quick, value: store.searchQuery.isEmpty)
        .onChange(of: store.searchQuery) {
            store.search()
        }
    }

    private func clear() {
        store.searchQuery = ""
    }

    private func close() {
        isFocused.wrappedValue = false
        store.endSearch()
        withAnimation(Motion.scene) { router.isSearching = false }
    }
}

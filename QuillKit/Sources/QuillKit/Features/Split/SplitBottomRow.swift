#if os(iOS)
import OSLog
import SwiftUI

/// The one line at the foot of the wide layout on iPad and iPhone Duo: the sidebar button and
/// Search under the list, and Compose in the trailing corner. Both columns place their pieces
/// from the screen's bottom edge with the same height and gap, so every piece is centred on
/// the same horizontal line by construction.
enum BottomRow {
    /// The height of the sidebar button, the Search pill and Compose.
    static let height = 48.0

    /// Where the row sits, measured once for the whole screen by `SplitRootView`.
    struct Placement: Equatable {
        /// The screen's bottom safe-area inset, without the keyboard.
        var bottomInset = 0.0
        /// The screen's trailing safe-area inset: the iPhone Duo's strip, or zero.
        var trailingInset = 0.0

        /// Distance from the screen's bottom edge to the row's bottom edge.
        var bottomGap: Double {
            max(bottomInset, Spacing.m) + Spacing.xxs
        }

        /// Distance from the screen's trailing edge to Compose's trailing edge: centred in the
        /// trailing strip when there is one wide enough, under the action rail; otherwise
        /// 20pt in from the content's trailing edge.
        var composeTrailing: Double {
            if trailingInset >= BottomRow.height + Spacing.m {
                (trailingInset - BottomRow.height) / 2
            } else {
                trailingInset + Spacing.l
            }
        }
    }

    #if DEBUG
    static let log = Logger(subsystem: "com.maxig0d.quill", category: "bottom-row")
    #endif
}

private struct BottomRowPlacementKey: EnvironmentKey {
    static let defaultValue = BottomRow.Placement()
}

extension EnvironmentValues {
    var bottomRowPlacement: BottomRow.Placement {
        get { self[BottomRowPlacementKey.self] }
        set { self[BottomRowPlacementKey.self] = newValue }
    }
}

extension View {
    /// Lays `content` along the screen's bottom edge at the row's gap, ignoring the container
    /// safe area so both columns share the screen edge as their basis. Set `ignoresKeyboard`
    /// for peripheral buttons (account, Compose) that should stay put when typing in Search.
    func bottomRow<Content: View>(
        alignment: Alignment,
        trailing: Double = 0,
        ignoresKeyboard: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        modifier(BottomRowModifier(alignment: alignment, trailing: trailing, ignoresKeyboard: ignoresKeyboard, row: content()))
    }

    /// Logs this view's global frame in Debug builds, to check the row's alignment by number.
    func logBottomRowFrame(_ name: String) -> some View {
        #if DEBUG
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            BottomRow.log.debug("\(name, privacy: .public) frame \(String(describing: frame), privacy: .public) midY \(frame.midY, privacy: .public)")
        }
        #else
        self
        #endif
    }
}

private struct BottomRowModifier<Row: View>: ViewModifier {
    @Environment(\.bottomRowPlacement) private var placement
    let alignment: Alignment
    let trailing: Double
    let ignoresKeyboard: Bool
    let row: Row

    func body(content: Content) -> some View {
        content.overlay {
            row
                .padding(.trailing, trailing)
                .padding(.bottom, placement.bottomGap)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .ignoresSafeArea(ignoresKeyboard ? [.container, .keyboard] : .container, edges: trailing > 0 ? [.bottom, .trailing] : .bottom)
        }
    }
}

/// The list's half of the row: the one sidebar button beside a Search pill, both on glass.
struct SplitSearchRow: View {
    @Environment(MailStore.self) private var store
    @Environment(\.toggleSidebar) private var toggleSidebar
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var store = store
        GlassEffectContainer(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Button(action: toggleSidebar) {
                    Label("Mailboxes", systemImage: "sidebar.leading")
                        .labelStyle(.iconOnly)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Palette.label)
                        .frame(width: BottomRow.height, height: BottomRow.height)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .logBottomRowFrame("sidebar")

                HStack(spacing: Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Palette.secondaryLabel)
                        .accessibilityHidden(true)
                    TextField("Search", text: $store.searchQuery)
                        .focused($isFocused)
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
                .padding(.leading, Spacing.m)
                .padding(.trailing, Spacing.xs)
                .frame(height: BottomRow.height)
                .contentShape(.capsule)
                .onTapGesture { isFocused = true }
                .glassEffect(.regular.interactive(), in: .capsule)
                .logBottomRowFrame("search")
            }
        }
        .padding(.horizontal, Spacing.m)
        .animation(Motion.quick, value: store.searchQuery.isEmpty)
        .onChange(of: store.selection) {
            isFocused = false
        }
    }

    private func clear() {
        store.searchQuery = ""
        isFocused = false
    }
}
#endif

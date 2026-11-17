import SwiftUI

/// Modifiers that exist on one platform only, wrapped so shared views stay free of `#if`.
extension View {
    /// Grouped cards on iOS, where the design calls for them. A plain inset list on macOS.
    @ViewBuilder
    func cardListStyle() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
        #else
        self.listStyle(.inset)
        #endif
    }

    @ViewBuilder
    func hidesNavigationBar(_ isHidden: Bool) -> some View {
        #if os(iOS)
        self.toolbar(isHidden ? .hidden : .visible, for: .navigationBar)
        #else
        self
        #endif
    }

    /// Removes the navigation bar's backdrop and the blur at the top scroll edge, for
    /// content that is laid out inside the bar's band and must stay crisp there.
    @ViewBuilder
    func clearsNavigationBar(_ isClear: Bool) -> some View {
        #if os(iOS)
        self.toolbarBackgroundVisibility(isClear ? .hidden : .automatic, for: .navigationBar)
            .scrollEdgeEffectHidden(isClear, for: .top)
        #else
        self
        #endif
    }

    /// Turns off capitalization and correction for addresses and search terms.
    @ViewBuilder
    func plainTextEntry() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self.autocorrectionDisabled()
        #endif
    }

    @ViewBuilder
    func emailEntry() -> some View {
        #if os(iOS)
        self.plainTextEntry()
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
        #else
        self.plainTextEntry()
        #endif
    }

    /// Hides the disclosure chevron that lists add to navigation links.
    @ViewBuilder
    func hidesNavigationLinkIndicator() -> some View {
        #if os(iOS)
        self.navigationLinkIndicatorVisibility(.hidden)
        #else
        self
        #endif
    }
}

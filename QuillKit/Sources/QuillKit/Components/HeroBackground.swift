import SwiftUI

/// The tonal gradient behind the Inbox, fading into the plain background.
struct HeroBackground: View {
    /// False draws the plain background, for every mailbox but the Inbox.
    var isTinted = true

    var body: some View {
        Palette.background
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Palette.heroTop, Palette.heroTop.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .containerRelativeFrame(.vertical) { height, _ in height * 0.55 }
                .opacity(isTinted ? 1 : 0)
            }
            .ignoresSafeArea()
            .animation(Motion.scene, value: isTinted)
    }
}

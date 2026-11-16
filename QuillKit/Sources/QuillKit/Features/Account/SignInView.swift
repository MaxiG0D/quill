import AuthenticationServices
import SwiftUI

/// The first screen: Quill's icon, its name and the way in.
struct SignInView: View {
    @Environment(AccountSession.self) private var session
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(AppIcon.stored().previewName, bundle: .module)
                .resizable()
                .frame(width: 104, height: 104)
                .clipShape(IconShape())
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
                .accessibilityHidden(true)
            Text("Quill")
                .textRole(.display)
                .foregroundStyle(Palette.label)
            GoogleSignInButton(isBusy: session.isSigningIn, action: signIn)
                .padding(.top, Spacing.xs)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            HeroBackground()
        }
    }

    private func signIn() {
        Task {
            await session.signIn(using: webAuthenticationSession)
        }
    }
}

#Preview {
    SignInView()
        .environment(AccountSession())
}

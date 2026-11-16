import SwiftUI

/// Shows the mailbox when someone is signed in and the sign-in screen when no one is.
struct SessionView: View {
    @Environment(AccountSession.self) private var session
    @State private var isShowingAlert = false

    var body: some View {
        ZStack {
            switch session.phase {
            case .launching:
                HeroBackground()
            case .signedOut:
                SignInView()
                    .transition(.opacity)
            case .ready:
                if let store = session.store {
                    RootView()
                        .environment(store)
                        .transition(.opacity)
                }
            }
        }
        .animation(Motion.scene, value: session.phase)
        .tint(Palette.accent)
        .task {
            await session.restore()
        }
        .alert("Couldn’t Sign In", isPresented: $isShowingAlert) {
            Button("OK", action: clearAlert)
        } message: {
            Text(session.alert ?? "")
        }
        .onChange(of: session.alert) {
            isShowingAlert = session.alert != nil
        }
    }

    private func clearAlert() {
        session.alert = nil
    }
}

#Preview {
    SessionView()
        .environment(AccountSession())
        .environment(Router())
}

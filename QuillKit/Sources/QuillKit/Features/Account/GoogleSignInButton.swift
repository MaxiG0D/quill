import SwiftUI

/// Google's sign-in button, drawn to its branding guidelines: the four-color G and
/// "Sign in with Google" on white with a gray outline, or on near-black in Dark Mode.
/// The colors are Google's, not Quill's, so they stay out of the palette.
struct GoogleSignInButton: View {
    var isBusy = false
    let action: () -> Void

    private static let fill = Color(light: 0xFFFFFF, dark: 0x131314)
    private static let stroke = Color(light: 0x747775, dark: 0x8E918F)
    private static let ink = Color(light: 0x1F1F1F, dark: 0xE3E3E3)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("GoogleMark", bundle: .module)
                    .accessibilityHidden(true)
                Text("Sign in with Google")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Self.ink)
            }
            .padding(.horizontal, 20)
            .frame(height: 48)
            .background(Self.fill, in: .capsule)
            .overlay {
                Capsule().strokeBorder(Self.stroke, lineWidth: 1)
            }
            .opacity(isBusy ? 0.6 : 1)
        }
        .buttonStyle(.pressable)
        .disabled(isBusy)
    }
}

#Preview {
    GoogleSignInButton {}
        .padding()
}

import CoreText
import SwiftUI

/// Google's sign-in button, drawn to its branding guidelines (updated 2026-07-07) and
/// to the pill in Google's iOS asset bundle: 44 pt tall, the 20 pt standard-colour G
/// 16 pt from the leading edge, 12 pt between the G and the label, 16 pt after the
/// label, and the label in Google Sans Medium 14/20. White with a #747775 outline, or
/// #131314 with #8E918F in Dark Mode. The colours are Google's, not Quill's, so they
/// stay out of the palette. Google documents no disabled look, so a busy button just
/// fades.
struct GoogleSignInButton: View {
    var isBusy = false
    let action: () -> Void

    private static let fill = Color(light: 0xFFFFFF, dark: 0x131314)
    private static let stroke = Color(light: 0x747775, dark: 0x8E918F)
    private static let ink = Color(light: 0x1F1F1F, dark: 0xE3E3E3)

    /// Google Sans ships in this package, so it is registered with the process before first use.
    private static let font: Font = {
        if let url = Bundle.module.url(forResource: "GoogleSans", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return .custom("GoogleSans-Regular_Medium", size: 14)
    }()

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("GoogleG", bundle: .module)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text("Sign in with Google")
                    .font(Self.font)
                    .lineSpacing(6)
                    .foregroundStyle(Self.ink)
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .frame(height: 44)
            .background(Self.fill, in: .capsule)
            .overlay {
                Capsule().strokeBorder(Self.stroke, lineWidth: 1)
            }
            .contentShape(.capsule)
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

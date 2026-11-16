import SwiftUI

/// Shrinks its label slightly while pressed, for custom buttons that have no system style.
struct PressableButtonStyle: ButtonStyle {
    var scale = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

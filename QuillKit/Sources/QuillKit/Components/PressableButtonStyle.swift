import SwiftUI

/// Shrinks its label slightly while pressed, for custom buttons that have no system style.
struct PressableButtonStyle: ButtonStyle {
    var scale = 0.94

    func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration, scale: scale)
    }
}

private struct PressableBody: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    let configuration: ButtonStyleConfiguration
    let scale: Double

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(!isEnabled ? 0.45 : (configuration.isPressed ? 0.85 : 1))
            .animation(reduceMotion ? nil : Motion.quick, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

import SwiftUI

extension LabelTone {
    /// The soft surface behind a chip, swatch or monogram.
    var fill: Color {
        switch self {
        case .teal: Color(light: 0xD4EBE5, dark: 0x173A36)
        case .slate: Color(light: 0xDCE2EE, dark: 0x1D2A3B)
        case .amber: Color(light: 0xF2E4CA, dark: 0x382D17)
        case .plum: Color(light: 0xEADDE7, dark: 0x32202E)
        case .olive: Color(light: 0xE2E7D0, dark: 0x283019)
        }
    }

    /// The text color that sits on `fill`.
    var ink: Color {
        switch self {
        case .teal: Color(light: 0x055552, dark: 0x96D9D2)
        case .slate: Color(light: 0x2C4465, dark: 0xACC6E9)
        case .amber: Color(light: 0x6E4C0C, dark: 0xE9CC94)
        case .plum: Color(light: 0x5E3A54, dark: 0xE4B9D7)
        case .olive: Color(light: 0x495517, dark: 0xC5CFA4)
        }
    }
}

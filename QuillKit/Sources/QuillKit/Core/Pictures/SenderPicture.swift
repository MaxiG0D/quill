import SwiftUI

/// A sender's picture, ready to draw.
struct SenderPicture {
    enum Kind {
        /// A person's own picture, which fills the tile.
        case person
        /// A company's logo, which sits whole on white.
        case logo
    }

    let image: Image
    let kind: Kind
}

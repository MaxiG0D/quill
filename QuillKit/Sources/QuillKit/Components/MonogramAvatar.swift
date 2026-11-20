import SwiftUI

/// A rounded tile with a person's picture, or their initials in the serif face when there is none.
struct MonogramAvatar: View {
    enum Size: Double {
        case small = 24, compact = 32, medium = 40, large = 48, floating = 54
    }

    @Environment(SenderPictures.self) private var pictures: SenderPictures?

    let contact: Contact
    var size: Size = .medium

    init(_ contact: Contact, size: Size = .medium) {
        self.contact = contact
        self.size = size
    }

    var body: some View {
        let picture = pictures?.picture(for: contact)
        Text(contact.initials)
            .font(.system(size: size.rawValue * 0.42, weight: .semibold, design: .serif))
            .foregroundStyle(contact.tone.ink)
            .frame(width: size.rawValue, height: size.rawValue)
            .background(contact.tone.fill)
            .overlay {
                // The initials stay underneath until the picture arrives, and if it never does.
                if let picture {
                    tile(picture)
                        .transition(.opacity)
                }
            }
            .clipShape(.rect(cornerRadius: size.rawValue * Radius.squircle))
            .animation(Motion.quick, value: picture != nil)
            .accessibilityHidden(true)
            .task(id: lookup) {
                await pictures?.resolve(contact)
            }
    }

    @ViewBuilder
    private func tile(_ picture: SenderPicture) -> some View {
        switch picture.kind {
        case .person:
            picture.image
                .resizable()
                .interpolation(.high)
                .scaledToFill()
        case .logo:
            picture.image
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white)
        }
    }

    /// Changes when the contact does, and when new pictures may have arrived for it.
    private var lookup: String {
        "\(contact.email) \(pictures?.revision ?? 0)"
    }
}

#Preview {
    HStack {
        MonogramAvatar(SampleData.priya, size: .large)
        MonogramAvatar(SampleData.dental)
        MonogramAvatar(SampleData.library, size: .compact)
        MonogramAvatar(SampleData.account, size: .small)
    }
    .padding()
}

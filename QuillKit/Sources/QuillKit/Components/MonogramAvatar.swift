import SwiftUI

/// A rounded tile with a person's picture, or their initials in the serif face when there is none.
struct MonogramAvatar: View {
    enum Size: Double {
        case small = 24, compact = 32, medium = 40, large = 48
    }

    let initials: String
    let tone: LabelTone
    var photoURL: URL?
    var size: Size = .medium

    init(_ contact: Contact, size: Size = .medium) {
        self.initials = contact.initials
        self.tone = contact.tone
        self.photoURL = contact.photoURL
        self.size = size
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size.rawValue * 0.42, weight: .semibold, design: .serif))
            .foregroundStyle(tone.ink)
            .frame(width: size.rawValue, height: size.rawValue)
            .background(tone.fill)
            .overlay {
                // The initials stay underneath until the picture arrives, and if it never does.
                if let photoURL {
                    AsyncImage(url: photoURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .clipShape(.rect(cornerRadius: size.rawValue * Radius.squircle))
            .accessibilityHidden(true)
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

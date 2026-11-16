import SwiftUI

/// A capsule naming a label, tinted by the label's tone.
struct LabelChip: View {
    let name: String
    /// Nil draws the neutral chip used for mailboxes such as Inbox.
    var tone: LabelTone?

    init(_ label: MailLabel) {
        self.name = label.name
        self.tone = label.tone
    }

    init(name: String, tone: LabelTone? = nil) {
        self.name = name
        self.tone = tone
    }

    var body: some View {
        Text(name)
            .textRole(.chip)
            .lineLimit(1)
            .foregroundStyle(tone?.ink ?? Palette.label)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(tone?.fill ?? Palette.fill, in: .capsule)
    }
}

#Preview {
    HStack {
        LabelChip(SampleData.house)
        LabelChip(SampleData.family)
        LabelChip(name: "Inbox")
    }
    .padding()
}

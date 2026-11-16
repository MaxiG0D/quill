import SwiftUI

/// Lays views out in rows, wrapping to a new row when one fills up.
struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.xs
    /// When set, the last view is given whatever width is left in its row, and only
    /// wraps when less than this much remains. Used for a text field after tokens.
    var flexibleTrailingMinWidth: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let widest = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                var size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                if isFlexible(index, in: subviews) {
                    size.width = max(bounds.maxX - x, 0)
                }
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func isFlexible(_ index: Int, in subviews: Subviews) -> Bool {
        flexibleTrailingMinWidth != nil && index == subviews.count - 1
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            if let minWidth = flexibleTrailingMinWidth, isFlexible(index, in: subviews) {
                size.width = minWidth
            }
            let gap = current.indices.isEmpty ? 0 : spacing
            if !current.indices.isEmpty, current.width + gap + size.width > width {
                rows.append(current)
                current = Row()
            }
            current.width += (current.indices.isEmpty ? 0 : spacing) + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

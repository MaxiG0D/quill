import SwiftUI
#if os(iOS)
import UIKit
#endif

/// One action revealed behind a swiped row. The first item on a side is the one a full swipe runs.
struct SwipeItem: Identifiable {
    let title: String
    let symbol: String
    let tint: Color
    /// Whether running it takes the row out of the list, so a full swipe slides the row away.
    let removesRow: Bool
    let action: () -> Void

    var id: String { title }
}

extension View {
    /// Closes an open swipe row as soon as the list starts scrolling.
    @ViewBuilder
    func closesSwipeRowsOnScroll() -> some View {
        #if os(iOS)
        onScrollPhaseChange { _, phase in
            if phase == .interacting, SwipeCoordinator.shared.openID != nil {
                SwipeCoordinator.shared.openID = nil
            }
        }
        #else
        self
        #endif
    }
}

#if os(iOS)
/// Keeps a single row open at a time, and closes it when the list scrolls.
@MainActor @Observable
final class SwipeCoordinator {
    static let shared = SwipeCoordinator()
    var openID: String?
}

extension View {
    /// Swipe actions with a pill that follows the finger. The modifier owns the row's insets, so the
    /// row slides across the whole cell and the pill fills exactly the space it leaves behind.
    func swipeRow(
        id: String,
        insets: EdgeInsets,
        isEnabled: Bool = true,
        leading: [SwipeItem],
        trailing: [SwipeItem]
    ) -> some View {
        modifier(SwipeRowModifier(id: id, insets: insets, isEnabled: isEnabled, leading: leading, trailing: trailing))
    }

}

private struct SwipeRowModifier: ViewModifier {
    let id: String
    let insets: EdgeInsets
    let isEnabled: Bool
    let leading: [SwipeItem]
    let trailing: [SwipeItem]

    @State private var offset: CGFloat = 0
    /// 0 while the actions share the space, 1 once the first one has taken it all.
    @State private var arm: CGFloat = 0
    @State private var isArmed = false
    /// Ticks only when the finger crosses the line, so settling and committing stay silent.
    @State private var crossings = 0
    @State private var startOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isCommitting = false
    @State private var width: CGFloat = 0

    private var coordinator: SwipeCoordinator { .shared }

    func body(content: Content) -> some View {
        content
            .padding(insets)
            .overlay {
                if offset != 0 && !isDragging {
                    Color.clear
                        .contentShape(.rect)
                        .onTapGesture { settle(to: 0, velocity: 0) }
                }
            }
            .offset(x: offset)
            .background {
                SwipeActionsLayer(offset: offset, arm: arm, leading: leading, trailing: trailing, onTap: tap)
            }
            .clipShape(.rect)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .gesture(SwipePan(isEnabled: isEnabled, onBegan: began, onChanged: changed, onEnded: ended))
            .sensoryFeedback(trigger: crossings) { _, _ in
                isArmed ? .impact(weight: .medium, intensity: 0.9) : .impact(weight: .light, intensity: 0.6)
            }
            .onChange(of: coordinator.openID) { _, open in
                if open != id, offset != 0, !isDragging, !isCommitting {
                    settle(to: 0, velocity: 0)
                }
            }
            .onChange(of: isEnabled) { _, enabled in
                if !enabled, offset != 0 { settle(to: 0, velocity: 0) }
            }
            .accessibilityActions {
                ForEach(accessibilityItems) { item in
                    Button(item.title, action: item.action)
                }
            }
            .listRowInsets(EdgeInsets())
    }

    private var accessibilityItems: [SwipeItem] {
        var seen = Set<String>()
        return (trailing + leading).filter { seen.insert($0.id).inserted }
    }

    // MARK: Geometry

    private static let unit: CGFloat = 74

    private func items(for value: CGFloat) -> [SwipeItem] {
        value < 0 ? trailing : leading
    }

    /// How far the row rests when it stays open on its buttons.
    private func openWidth(_ count: Int) -> CGFloat {
        CGFloat(count) * Self.unit + SwipeActionsLayer.pad * CGFloat(count + 1)
    }

    /// Past this distance a release runs the first action.
    private func armDistance(_ count: Int) -> CGFloat {
        max(openWidth(count) + 56, width * 0.52)
    }

    /// The finger's position, with growing resistance past the row's width or toward a side
    /// that has nothing to reveal.
    private func resisted(_ raw: CGFloat) -> CGFloat {
        let sign: CGFloat = raw < 0 ? -1 : 1
        let distance = abs(raw)
        if items(for: raw).isEmpty {
            return sign * rubberBand(distance, limit: 28)
        }
        let limit = max(width, 1)
        guard distance > limit else { return raw }
        return sign * (limit + rubberBand(distance - limit, limit: 36))
    }

    private func rubberBand(_ distance: CGFloat, limit: CGFloat) -> CGFloat {
        limit * (1 - 1 / (distance / limit * 0.55 + 1))
    }

    // MARK: Gesture

    private func began() {
        isDragging = true
        startOffset = offset
        if coordinator.openID != id { coordinator.openID = id }
    }

    private func changed(_ translation: CGFloat) {
        guard !isCommitting else { return }
        let value = resisted(startOffset + translation)
        offset = value
        updateArm(for: value)
    }

    private func ended(_ velocity: CGFloat) {
        isDragging = false
        guard !isCommitting else { return }
        let side = items(for: offset)
        guard offset != 0, let first = side.first else {
            settle(to: 0, velocity: velocity)
            return
        }
        let sign: CGFloat = offset < 0 ? -1 : 1
        let outward = velocity * sign
        if isArmed && outward > -400 {
            commit(first, sign: sign, velocity: velocity)
            return
        }
        let open = openWidth(side.count)
        let projected = abs(offset) + outward * 0.15
        if projected > open * 0.6 && outward > -500 {
            settle(to: sign * open, velocity: velocity)
        } else {
            settle(to: 0, velocity: velocity)
        }
    }

    private func updateArm(for value: CGFloat) {
        let side = items(for: value)
        guard !side.isEmpty else {
            if isArmed { crossings += 1 }
            return setArmed(false)
        }
        let threshold = armDistance(side.count)
        let distance = abs(value)
        // A little hysteresis, so resting a finger on the line doesn't flicker.
        let armed = isArmed ? distance > threshold - 20 : distance > threshold
        if armed != isArmed { crossings += 1 }
        setArmed(armed)
    }

    private func setArmed(_ armed: Bool) {
        guard armed != isArmed else { return }
        isArmed = armed
        withAnimation(.spring(duration: 0.36, bounce: 0.32)) { arm = armed ? 1 : 0 }
    }

    // MARK: Motion

    private func settle(to target: CGFloat, velocity: CGFloat) {
        let distance = target - offset
        let relative = distance == 0 ? 0 : min(max(velocity / distance, -10), 10)
        withAnimation(.interpolatingSpring(duration: 0.44, bounce: target == 0 ? 0.1 : 0.18, initialVelocity: relative)) {
            offset = target
        }
        setArmed(false)
        if target == 0 {
            if coordinator.openID == id { coordinator.openID = nil }
        } else if coordinator.openID != id {
            coordinator.openID = id
        }
    }

    private func tap(_ item: SwipeItem) {
        commit(item, sign: offset < 0 ? -1 : 1, velocity: 0)
    }

    private func commit(_ item: SwipeItem, sign: CGFloat, velocity: CGFloat) {
        guard item.removesRow else {
            item.action()
            settle(to: 0, velocity: velocity)
            return
        }
        isCommitting = true
        if !isArmed {
            withAnimation(.easeOut(duration: 0.16)) { arm = 1 }
        }
        let target = sign * (width + Spacing.xs)
        withAnimation(.easeOut(duration: 0.16)) {
            offset = target
        } completion: {
            item.action()
            if coordinator.openID == id { coordinator.openID = nil }
            // The row normally leaves with the action. If it stays (the change failed), bring it back.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                isCommitting = false
                isArmed = false
                withAnimation(.interpolatingSpring(duration: 0.44, bounce: 0.1)) {
                    offset = 0
                    arm = 0
                }
            }
        }
    }
}

/// The pills behind the row. Animatable, so the pills track the row through every spring frame.
private struct SwipeActionsLayer: View, Animatable {
    var offset: CGFloat
    var arm: CGFloat
    let leading: [SwipeItem]
    let trailing: [SwipeItem]
    let onTap: (SwipeItem) -> Void

    static let pad: CGFloat = 6

    nonisolated var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(offset, arm) }
        set {
            offset = newValue.first
            arm = newValue.second
        }
    }

    var body: some View {
        let isTrailing = offset < 0
        // Left to right on screen. The first action sits at the outer edge, like the system's.
        let shown: [SwipeItem] = isTrailing ? trailing.reversed() : leading
        let primaryID = (isTrailing ? trailing : leading).first?.id
        let reveal = abs(offset)
        let progress = min(max(arm, 0), 1)
        let spacing = Self.pad * (1 - progress)
        let count = CGFloat(max(shown.count, 1))
        let available = max(0, reveal - 2 * Self.pad - spacing * (count - 1))
        let even = available / count

        GeometryReader { proxy in
            let pillHeight = max(0, proxy.size.height - 2 * Self.pad)
            HStack(spacing: spacing) {
                ForEach(shown) { item in
                    let isPrimary = item.id == primaryID
                    let pillWidth = isPrimary ? lerp(even, available, progress) : lerp(even, 0, progress)
                    pill(item, width: pillWidth, height: pillHeight, isPrimary: isPrimary, isTrailing: isTrailing, progress: progress)
                }
            }
            .padding(.horizontal, Self.pad)
            .frame(width: reveal, height: proxy.size.height, alignment: isTrailing ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: isTrailing ? .trailing : .leading)
        }
        .opacity(reveal > 0.5 ? 1 : 0)
    }

    private func pill(_ item: SwipeItem, width: CGFloat, height fullHeight: CGFloat, isPrimary: Bool, isTrailing: Bool, progress: CGFloat) -> some View {
        // Starts as a dot, grows into a circle, then stretches into a capsule.
        let height = min(fullHeight, width)
        // Centered while the actions share the space; once armed, the icon rides the row's edge.
        let rowEdge = isTrailing ? min(width / 2, fullHeight / 2) : max(width / 2, width - fullHeight / 2)
        let iconCenter = lerp(width / 2, rowEdge, isPrimary ? progress : 0)
        let grow = min(max((width - 10) / max(fullHeight * 0.7, 1), 0.45), 1)
        let pop = isPrimary ? 1 + 0.18 * sin(.pi * progress) : 1
        let iconOpacity = min(max((width - 22) / 16, 0), 1)

        return Button { onTap(item) } label: {
            Capsule()
                .fill(item.tint.gradient)
                .frame(width: max(width, 0), height: max(height, 0))
                .overlay(alignment: .leading) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Palette.onFill)
                        .frame(width: 32, height: 32)
                        .scaleEffect(grow * pop)
                        .opacity(iconOpacity)
                        .offset(x: iconCenter - 16)
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .opacity(min(max(width / 18, 0), 1))
        .allowsHitTesting(width > 24)
        .accessibilityLabel(item.title)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

/// A horizontal pan that only starts when the finger moves sideways, so vertical scrolling stays free.
private struct SwipePan: UIGestureRecognizerRepresentable {
    var isEnabled: Bool
    var onBegan: () -> Void
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began:
            onBegan()
            onChanged(recognizer.translation(in: recognizer.view).x)
        case .changed:
            onChanged(recognizer.translation(in: recognizer.view).x)
        case .ended:
            onEnded(recognizer.velocity(in: recognizer.view).x)
        case .cancelled, .failed:
            onEnded(0)
        default:
            break
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isEnabled = true

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled, let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.3
        }
    }
}
#endif

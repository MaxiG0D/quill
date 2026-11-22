import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

/// The long-press view of a sign-in code alert: the sender and the code, large. Its Copy
/// action is handled here, in front, which is where iOS allows a clipboard write. A Live
/// Activity button or a background notification action runs in the background, where the
/// write is silently dropped.
final class CodeNotificationViewController: UIViewController, UNNotificationContentExtension {
    private var code: String?
    private let host = UIHostingController(rootView: CodeCard(sender: "", display: ""))

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(host)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        code = content.userInfo["code"] as? String
        host.rootView = CodeCard(sender: content.title, display: content.body)
    }

    func didReceive(
        _ response: UNNotificationResponse,
        completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void
    ) {
        guard response.actionIdentifier == "COPY_CODE", let code else {
            completion(.dismissAndForwardAction)
            return
        }
        UIPasteboard.general.string = code
        // Quill hears about it too, to end the code's Live Activity on every device.
        completion(.dismissAndForwardAction)
    }
}

private struct CodeCard: View {
    let sender: String
    let display: String

    private let teal = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x4C / 255, green: 0xC2 / 255, blue: 0xB5 / 255, alpha: 1)
            : UIColor(red: 0x0B / 255, green: 0x6E / 255, blue: 0x69 / 255, alpha: 1)
    })

    var body: some View {
        HStack(spacing: 14) {
            Text(sender.first.map { String($0).uppercased() } ?? "")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(teal)
                .frame(width: 44, height: 44)
                .background(teal.opacity(0.18), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(sender)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(display)
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

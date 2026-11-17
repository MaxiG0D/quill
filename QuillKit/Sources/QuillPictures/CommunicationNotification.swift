import Intents
import UserNotifications

/// Turns a mail notification into a communication notification, which shows the sender's
/// picture where the app icon would be.
public enum CommunicationNotification {
    /// `content` with `picture` as the sender's picture. Unchanged if the system declines.
    public static func decorate(
        _ content: UNNotificationContent, sender: String, address: String, picture: Data
    ) -> UNNotificationContent {
        let person = INPerson(
            personHandle: INPersonHandle(value: address, type: .emailAddress),
            nameComponents: nil,
            displayName: sender,
            image: INImage(imageData: picture),
            contactIdentifier: nil,
            customIdentifier: address
        )
        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: content.body,
            speakableGroupName: nil,
            conversationIdentifier: content.threadIdentifier,
            serviceName: nil,
            sender: person,
            attachments: nil
        )
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        interaction.donate(completion: nil)

        guard let updated = try? content.updating(from: intent) else { return content }
        // The subject, which the system's version of the alert has no place for, stays.
        guard !content.subtitle.isEmpty, updated.subtitle.isEmpty,
              let copy = updated.mutableCopy() as? UNMutableNotificationContent else { return updated }
        copy.subtitle = content.subtitle
        return copy
    }
}

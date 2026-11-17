import { decodeEntities, decodeHeader, header, senderAddress, senderName } from "./text.js";

/** The most notifications one delivery from Gmail turns into. After a gap, the newest are enough. */
export const burstLimit = 6;

/**
 * The messages a stretch of mailbox history added to the Inbox, oldest first, without repeats.
 * `history` is the `history` array from Gmail's history.list.
 */
export function addedToInbox(history) {
  const seen = new Set();
  const ids = [];
  for (const record of history ?? []) {
    for (const added of record.messagesAdded ?? []) {
      const { id, labelIds = [] } = added.message ?? {};
      if (!id || seen.has(id) || !labelIds.includes("INBOX")) continue;
      seen.add(id);
      ids.push(id);
    }
  }
  return ids;
}

/**
 * True when a message, as it stands now, deserves a notification: still unread in the
 * Inbox, and not something the account wrote itself.
 */
export function isWaiting(message) {
  const labels = message.labelIds ?? [];
  return (
    labels.includes("INBOX") &&
    labels.includes("UNREAD") &&
    !labels.includes("SENT") &&
    !labels.includes("DRAFT")
  );
}

/**
 * The APNs payload for a message. The thread ID groups a conversation's notifications
 * and tells Quill what to open, and `content-available` lets Quill fetch the mail ahead
 * of the tap. `mutable-content` and `sender` let Quill's notification extension put the
 * sender's picture on the alert before it shows; without a picture the alert is unchanged.
 */
export function payload(message, badge) {
  const from = header(message, "From");
  const sender = senderAddress(from);
  return {
    ...(sender && { sender }),
    aps: {
      alert: {
        title: senderName(from),
        subtitle: decodeHeader(header(message, "Subject") ?? ""),
        body: decodeEntities(message.snippet ?? "").trim(),
      },
      sound: "default",
      badge,
      "thread-id": message.threadId,
      "content-available": 1,
      "mutable-content": 1,
    },
  };
}

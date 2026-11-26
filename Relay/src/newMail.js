import { display, signInCode } from "./code.js";
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

/** True when a stretch of history holds a change another device should pick up: mail deleted or relabelled. */
export function hasChanges(history) {
  return (history ?? []).some(
    (record) => record.messagesDeleted?.length || record.labelsAdded?.length || record.labelsRemoved?.length,
  );
}

/** Thread IDs whose labels changed or whose messages were deleted, without repeats. */
export function changedThreads(history) {
  const seen = new Set();
  const ids = [];
  for (const record of history ?? []) {
    for (const list of [record.messagesDeleted, record.labelsAdded, record.labelsRemoved]) {
      for (const item of list ?? []) {
        const id = item.message?.threadId;
        if (!id || seen.has(id)) continue;
        seen.add(id);
        ids.push(id);
      }
    }
  }
  return ids;
}

/**
 * A push with no banner or sound: updates the app icon badge immediately (when given)
 * and wakes Quill with the changed thread IDs so archived, deleted and read mail updates at once.
 */
export function syncPayload(badge, threads = []) {
  const listed = threads.slice(-12);
  return {
    ...(listed.length && { threads: listed }),
    aps: {
      ...(badge !== undefined && { badge }),
      "content-available": 1,
    },
    sync: true,
  };
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
  const subject = decodeHeader(header(message, "Subject") ?? "");
  const snippet = decodeEntities(message.snippet ?? "").trim();
  const code = signInCode(`${subject} ${snippet}`);
  // A sign-in code is the whole alert, with a Copy action to take it without opening Quill.
  // Both categories carry Archive and Delete.
  const alert = code
    ? { title: senderName(from), body: display(code) }
    : { title: senderName(from), subtitle: subject, body: snippet };
  return {
    ...(sender && { sender }),
    ...(code && { code }),
    aps: {
      alert,
      category: code ? "SIGN_IN_CODE" : "NEW_MAIL",
      sound: "default",
      badge,
      "thread-id": message.threadId,
      "content-available": 1,
      "mutable-content": 1,
    },
  };
}

/** How long a sign-in code's Live Activity stays up, in seconds. The relay ends it then, whatever happens. */
export const codeLifetime = 60;

/**
 * The push that starts a Live Activity for a message carrying a sign-in code, or null when
 * it carries none. It starts silently: the alert already announced the message.
 */
export function signInActivity(message, now = Date.now()) {
  const from = header(message, "From");
  const subject = decodeHeader(header(message, "Subject") ?? "");
  const code = signInCode(`${subject} ${decodeEntities(message.snippet ?? "")}`);
  if (!code) return null;
  const seconds = Math.floor(now / 1000);
  return {
    aps: {
      timestamp: seconds,
      event: "start",
      "attributes-type": "SignInCodeAttributes",
      attributes: {},
      "content-state": { sender: senderName(from), code, display: display(code), ...(subject && { subject }), expiresAt: seconds + codeLifetime },
      "stale-date": seconds + codeLifetime,
      // Apple asks for an alert on a start push, since the app is not running to make one.
      alert: { title: senderName(from), body: display(code) },
    },
  };
}

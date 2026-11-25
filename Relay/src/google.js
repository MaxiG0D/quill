// The Google calls the relay makes on an account's behalf.

const gmail = "https://gmail.googleapis.com/gmail/v1/users/me";

/** Thrown when Google has withdrawn the account's sign-in, so the relay should forget it. */
export class SignedOut extends Error {}

/** A failed Google call, with its HTTP status. */
export class GoogleError extends Error {
  constructor(status, message) {
    super(`Google ${status}: ${message}`);
    this.status = status;
  }
}

async function json(response) {
  const text = await response.text();
  if (response.ok) return text ? JSON.parse(text) : {};
  throw new GoogleError(response.status, text.slice(0, 300));
}

/** Who an access token belongs to and which client it was issued to. */
export async function tokenInfo(accessToken) {
  const url = new URL("https://oauth2.googleapis.com/tokeninfo");
  url.searchParams.set("access_token", accessToken);
  return json(await fetch(url));
}

/** A fresh access token from a refresh token. */
export async function accessToken(clientID, refreshToken) {
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    body: new URLSearchParams({ client_id: clientID, grant_type: "refresh_token", refresh_token: refreshToken }),
  });
  if (response.status === 400 || response.status === 401) {
    const failure = await response.json().catch(() => ({}));
    if (failure.error === "invalid_grant") throw new SignedOut();
    throw new GoogleError(response.status, failure.error ?? "");
  }
  return (await json(response)).access_token;
}

/** Gmail for one account. */
export class Mailbox {
  #token;

  constructor(accessToken) {
    this.#token = accessToken;
  }

  async #call(path, { method = "GET", query = [], body } = {}) {
    const url = new URL(gmail + path);
    for (const [name, value] of query) url.searchParams.append(name, value);
    return json(
      await fetch(url, {
        method,
        headers: { authorization: `Bearer ${this.#token}`, ...(body ? { "content-type": "application/json" } : {}) },
        body: body ? JSON.stringify(body) : undefined,
      }),
    );
  }

  async address() {
    return (await this.#call("/profile")).emailAddress.toLowerCase();
  }

  /** Asks Gmail to publish Inbox changes to the topic for the next seven days. */
  watch(topic) {
    return this.#call("/watch", {
      method: "POST",
      body: { topicName: topic, labelIds: ["INBOX"], labelFilterBehavior: "include" },
    });
  }

  stop() {
    return this.#call("/stop", { method: "POST" });
  }

  /** Every history record since `startHistoryId`: mail added, deleted, and relabelled (archived, read, starred). */
  async history(startHistoryId) {
    const records = [];
    let pageToken;
    do {
      const query = [
        ["startHistoryId", startHistoryId],
        ["historyTypes", "messageAdded"],
        ["historyTypes", "messageDeleted"],
        ["historyTypes", "labelAdded"],
        ["historyTypes", "labelRemoved"],
      ];
      if (pageToken) query.push(["pageToken", pageToken]);
      const page = await this.#call("/history", { query });
      records.push(...(page.history ?? []));
      pageToken = page.nextPageToken;
    } while (pageToken);
    return records;
  }

  /** A message's labels, summary, sender and subject. Null when it no longer exists. */
  async message(id) {
    try {
      return await this.#call(`/messages/${id}`, {
        query: [
          ["format", "metadata"],
          ["metadataHeaders", "From"],
          ["metadataHeaders", "Subject"],
        ],
      });
    } catch (error) {
      if (error instanceof GoogleError && error.status === 404) return null;
      throw error;
    }
  }

  /**
   * How many threads are unread, for the badge: Gmail's own number, which counts only the
   * Primary category. Primary's label tally also covers archived mail, so those are counted
   * from the Inbox itself, in pages. Without categories (label missing, failing or empty),
   * or when the device asks for the whole Inbox (its tabs are off, so its Inbox lists
   * Promotions and the rest too), it is the whole Inbox, whose tally is exact.
   */
  async unreadCount({ allInbox = false } = {}) {
    if (allInbox) return (await this.#call("/labels/INBOX")).threadsUnread ?? 0;
    try {
      const primary = await this.#call("/labels/CATEGORY_PERSONAL");
      if ((primary.threadsTotal ?? 0) > 0) return await this.#unreadPrimaryInbox();
    } catch {
      // Categories are off or unavailable: count the whole Inbox.
    }
    return (await this.#call("/labels/INBOX")).threadsUnread ?? 0;
  }

  async #unreadPrimaryInbox() {
    let count = 0;
    let pageToken;
    for (let page = 0; page < 10; page++) {
      const query = [["maxResults", "500"]];
      for (const label of ["INBOX", "CATEGORY_PERSONAL", "UNREAD"]) query.push(["labelIds", label]);
      if (pageToken) query.push(["pageToken", pageToken]);
      const list = await this.#call("/threads", { query });
      count += (list.threads ?? []).length;
      pageToken = list.nextPageToken;
      if (!pageToken) break;
    }
    return count;
  }
}

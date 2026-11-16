import { GoogleError, Mailbox, SignedOut, accessToken, tokenInfo } from "./google.js";
import { addedToInbox, burstLimit, isWaiting, payload } from "./newMail.js";

/** A request the relay turns away, with the HTTP status to answer with. */
export class Refused extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

/** The watch is renewed once it has less than this left of its seven days. */
const renewalMargin = 3 * 24 * 60 * 60 * 1000;

/**
 * The relay's work: it keeps a Gmail watch going for each registered account, and turns
 * each change Gmail reports into notifications for that account's devices.
 */
export class Relay {
  #config;
  #accounts;
  #apns;
  /** The work in flight for each account, so one account's deliveries are handled in order. */
  #queues = new Map();

  constructor({ config, accounts, apns }) {
    this.#config = config;
    this.#accounts = accounts;
    this.#apns = apns;
  }

  /** Registers a device for the account a Quill access token belongs to. */
  async register(bearer, { deviceToken, environment, platform, refreshToken }) {
    if (!/^[0-9a-f]{64,200}$/i.test(deviceToken ?? "") || !refreshToken) {
      throw new Refused(400, "A device token and a refresh token are required.");
    }
    const email = await this.#identify(bearer);
    // The refresh token must open the same mailbox the caller proved it owns.
    const mailbox = await this.#mailbox(refreshToken);
    if ((await mailbox.address()) !== email) throw new Refused(403, "The refresh token is for another account.");

    return this.#inOrder(email, async () => {
      await this.#accounts.addDevice(email, {
        deviceToken: deviceToken.toLowerCase(),
        environment: environment === "development" ? "development" : "production",
        platform: platform === "macos" ? "macos" : "ios",
        refreshToken,
      });
      await this.#watch(email, mailbox, await this.#accounts.get(email), true);
    });
  }

  /** Forgets a device, and the whole account once its last device is gone. */
  async unregister(bearer, { deviceToken }) {
    const email = await this.#identify(bearer);
    return this.#inOrder(email, async () => {
      const account = await this.#accounts.get(email);
      if (!account) return;
      const remaining = await this.#accounts.removeDevice(email, (deviceToken ?? "").toLowerCase());
      if (remaining > 0) return;
      try {
        await (await this.#mailbox(account.refreshToken)).stop();
      } catch {
        // The watch runs out by itself within a week.
      }
      await this.#accounts.remove(email);
    });
  }

  /** Handles one notice from Gmail that a mailbox changed. */
  async mailboxChanged({ emailAddress, historyId }) {
    const email = (emailAddress ?? "").toLowerCase();
    if (!email) return;
    return this.#inOrder(email, async () => {
      const account = await this.#accounts.get(email);
      if (!account?.refreshToken || !Object.keys(account.devices ?? {}).length) return;

      let mailbox;
      try {
        mailbox = await this.#mailbox(account.refreshToken);
      } catch (error) {
        if (!(error instanceof SignedOut)) throw error;
        await this.#accounts.remove(email);
        return;
      }

      const start = account.historyId;
      if (start && BigInt(historyId) > BigInt(start)) {
        let records = [];
        try {
          records = await mailbox.history(start);
        } catch (error) {
          // Gmail keeps about a week of history. Past that, the relay starts again from now.
          if (!(error instanceof GoogleError && error.status === 404)) throw error;
        }
        await this.#notify(email, account, mailbox, addedToInbox(records));
      }
      if (!start || BigInt(historyId) > BigInt(start)) {
        await this.#accounts.update(email, { historyId: String(historyId) });
      }
      await this.#watch(email, mailbox, account, false);
    });
  }

  async #notify(email, account, mailbox, ids) {
    const messages = [];
    for (const id of ids.slice(-burstLimit)) {
      const message = await mailbox.message(id);
      if (message && isWaiting(message)) messages.push(message);
    }
    if (!messages.length) return;

    const badge = await mailbox.unreadCount();
    for (const [deviceToken, device] of Object.entries(account.devices)) {
      const name = `${device.platform} ${deviceToken.slice(0, 8)}`;
      let delivered = 0;
      for (const message of messages) {
        try {
          const { outcome, environment, reason } = await this.#apns.send({
            deviceToken,
            environment: device.environment,
            payload: payload(message, badge),
            collapseID: message.id,
          });
          if (outcome === "gone") {
            console.warn(`Apple no longer knows ${name} (${reason}), so it is forgotten.`);
            await this.#accounts.removeDevice(email, deviceToken);
            break;
          }
          if (environment !== device.environment) {
            console.warn(`${name} is in Apple's ${environment} service, not ${device.environment}.`);
            device.environment = environment;
            await this.#accounts.setEnvironment(email, deviceToken, environment);
          }
          delivered += 1;
        } catch (error) {
          console.error(`Push failed for ${name}: ${error.message}`);
          break;
        }
      }
      if (delivered) console.log(`Sent ${delivered} to ${name}.`);
    }
  }

  /** Starts the Gmail watch, or renews it when it is running out. */
  async #watch(email, mailbox, account, isForced) {
    const expiry = Number(account?.watchExpiration ?? 0);
    if (!isForced && expiry - Date.now() > renewalMargin) return;
    const watch = await mailbox.watch(this.#config.topic);
    const fields = { watchExpiration: String(watch.expiration) };
    // History starts where the first watch did. From then on, deliveries move it forward.
    if (!account?.historyId) fields.historyId = String(watch.historyId);
    await this.#accounts.update(email, fields);
  }

  async #identify(bearer) {
    if (!bearer) throw new Refused(401, "Sign in first.");
    let info;
    try {
      info = await tokenInfo(bearer);
    } catch (error) {
      console.warn(`tokeninfo failed: ${error.status ?? ""} ${error.message ?? error}`);
      throw new Refused(401, "Sign in first.");
    }
    if (info.aud !== this.#config.googleClientID || !info.email) {
      throw new Refused(403, "This token was not issued to Quill.");
    }
    return info.email.toLowerCase();
  }

  async #mailbox(refreshToken) {
    return new Mailbox(await accessToken(this.#config.googleClientID, refreshToken));
  }

  #inOrder(email, work) {
    const previous = this.#queues.get(email) ?? Promise.resolve();
    const next = previous.catch(() => {}).then(work);
    this.#queues.set(email, next);
    next.catch(() => {}).finally(() => {
      if (this.#queues.get(email) === next) this.#queues.delete(email);
    });
    return next;
  }
}

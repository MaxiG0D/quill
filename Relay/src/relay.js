import { GoogleError, Mailbox, SignedOut, accessToken, tokenInfo } from "./google.js";
import { addedToInbox, burstLimit, codeLifetime, hasChanges, isWaiting, payload, signInActivity, syncPayload } from "./newMail.js";

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
  /** Calls `expire` later: `(seconds, { email, code })`. Cloud Tasks in production. */
  #later;
  /** The work in flight for each account, so one account's deliveries are handled in order. */
  #queues = new Map();

  constructor({ config, accounts, apns, later }) {
    this.#config = config;
    this.#accounts = accounts;
    this.#apns = apns;
    this.#later = later;
  }

  /** Registers a device for the account a Quill access token belongs to. */
  async register(bearer, { deviceToken, environment, platform, refreshToken, activityStartToken }) {
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
        activityStartToken: /^[0-9a-f]{64,400}$/i.test(activityStartToken ?? "") ? activityStartToken.toLowerCase() : undefined,
      });
      await this.#watch(email, mailbox, await this.#accounts.get(email), true);
    });
  }

  /** Remembers a Live Activity of this account, so a Copy elsewhere can end it. */
  async registerActivity(bearer, { deviceToken, activityToken, code }) {
    if (!/^[0-9a-f]{64,400}$/i.test(activityToken ?? "") || !/^\d{3,12}$/.test(code ?? "")) {
      throw new Refused(400, "An activity token and a code are required.");
    }
    const email = await this.#identify(bearer);
    return this.#inOrder(email, async () => {
      const account = await this.#accounts.get(email);
      const device = account?.devices?.[(deviceToken ?? "").toLowerCase()];
      if (!device) throw new Refused(404, "That device is not registered.");
      await this.#accounts.addActivity(email, {
        activityToken: activityToken.toLowerCase(),
        deviceToken: deviceToken.toLowerCase(),
        code,
        environment: device.environment,
      });
    });
  }

  /** Ends every Live Activity of this account that shows `code`, because it was copied or closed. */
  async dismiss(bearer, { code }) {
    if (!/^\d{3,12}$/.test(code ?? "")) throw new Refused(400, "A code is required.");
    await this.#endActivities(await this.#identify(bearer), code);
  }

  /** Ends a code's Live Activities once its minute is up. Cloud Tasks calls it through `#later`. */
  async expire({ email, code }) {
    if (!email || !/^\d{3,12}$/.test(code ?? "")) return;
    await this.#endActivities(email.toLowerCase(), code);
  }

  async #endActivities(email, code) {
    const activities = await this.#accounts.takeActivities(email, code);
    let ended = 0;
    const seconds = Math.floor(Date.now() / 1000);
    for (const [activityToken, activity] of activities) {
      try {
        await this.#apns.send({
          deviceToken: activityToken,
          environment: activity.environment,
          payload: {
            aps: {
              timestamp: seconds,
              event: "end",
              "dismissal-date": seconds,
              "content-state": { sender: "", code, display: "", subject: null, expiresAt: null },
            },
          },
          pushType: "liveactivity",
        });
        ended += 1;
      } catch (error) {
        console.error(`Ending a Live Activity failed: ${error.message}`);
      }
    }
    console.log(`Ended ${ended} Live Activities for code.`);
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
        if (hasChanges(records)) await this.#sync(email, account);
      }
      if (!start || BigInt(historyId) > BigInt(start)) {
        await this.#accounts.update(email, { historyId: String(historyId) });
      }
      await this.#watch(email, mailbox, account, false);
    });
  }

  /**
   * Sends the caller's own devices a made-up sign-in code, the way a real email would, so
   * the alert and the Live Activity can be tried without waiting for one.
   */
  async testCode(bearer) {
    const email = await this.#identify(bearer);
    const account = await this.#accounts.get(email);
    if (!account || !Object.keys(account.devices ?? {}).length) throw new Refused(404, "No devices are registered.");
    const code = String(100000 + Math.floor(Math.random() * 900000));
    const sender = ["GitHub", "Google", "Stripe", "Apple"][Math.floor(Math.random() * 4)];
    const message = {
      id: `test-${Date.now()}`,
      threadId: "test",
      snippet: `Your ${sender} verification code is ${code}.`,
      payload: { headers: [{ name: "From", value: `${sender} <test@quill.invalid>` }, { name: "Subject", value: `Your ${sender} verification code` }] },
    };
    await this.#send(email, account, [message], undefined);
  }

  async #notify(email, account, mailbox, ids) {
    const messages = [];
    for (const id of ids.slice(-burstLimit)) {
      const message = await mailbox.message(id);
      if (message && isWaiting(message)) messages.push(message);
    }
    if (!messages.length) return;

    await this.#send(email, account, messages, await mailbox.unreadCount());
  }

  /** Wakes every device of the account without an alert, so archived, deleted and read mail shows up at once. */
  async #sync(email, account) {
    for (const [deviceToken, device] of Object.entries(account.devices)) {
      try {
        const { outcome, environment } = await this.#apns.send({
          deviceToken,
          environment: device.environment,
          payload: syncPayload,
          collapseID: "sync",
          pushType: "background",
          priority: 5,
        });
        if (outcome === "gone") await this.#accounts.removeDevice(email, deviceToken);
        else if (environment !== device.environment) await this.#accounts.setEnvironment(email, deviceToken, environment);
      } catch (error) {
        console.error(`Sync push failed for ${device.platform} ${deviceToken.slice(0, 8)}: ${error.message}`);
      }
    }
  }

  async #send(email, account, messages, badge) {
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
      await this.#startActivity(email, deviceToken, device, name, messages);
    }
    const code = signInActivity(messages.findLast((message) => signInActivity(message)) ?? messages.at(-1))?.aps["content-state"].code;
    if (!code || !this.#later) return;
    try {
      await this.#later(codeLifetime, { email, code });
    } catch (error) {
      console.error(`Scheduling the end of a Live Activity failed: ${error.message}`);
    }
  }

  /** Puts the newest sign-in code on the device's Lock Screen and Dynamic Island. */
  async #startActivity(email, deviceToken, device, name, messages) {
    const activity = signInActivity(messages.findLast((message) => signInActivity(message)) ?? messages.at(-1));
    if (!activity) return;
    if (!device.activityStartToken) {
      console.log(`${name} has no Live Activity token, so only the alert was sent.`);
      return;
    }
    try {
      const { outcome } = await this.#apns.send({
        deviceToken: device.activityStartToken,
        environment: device.environment,
        payload: activity,
        pushType: "liveactivity",
      });
      console.log(`Live Activity for ${name}: ${outcome}.`);
      if (outcome === "gone") await this.#accounts.clearActivityStartToken(email, deviceToken);
    } catch (error) {
      console.error(`Live Activity failed for ${name}: ${error.message}`);
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

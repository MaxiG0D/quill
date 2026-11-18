import { createPrivateKey, sign } from "node:crypto";
import http2 from "node:http2";

const hosts = {
  production: "https://api.push.apple.com",
  development: "https://api.sandbox.push.apple.com",
};

/** Sends notifications through Apple's push service, signed with the team's push key. */
export class APNs {
  #key;
  #keyID;
  #teamID;
  #topic;
  #token;
  #sessions = new Map();

  constructor({ key, keyID, teamID, topic }) {
    this.#key = createPrivateKey(key);
    this.#keyID = keyID;
    this.#teamID = teamID;
    this.#topic = topic;
  }

  /**
   * Sends one notification. Resolves to `{ outcome, environment, reason }`: the outcome is
   * "sent", or "gone" when Apple says the device token is no longer good and should be
   * forgotten. Throws on anything else.
   *
   * A token only works in the push service that issued it, and a device can report the
   * wrong one, so a token Apple does not recognise is tried in the other service before it
   * is given up on. `environment` is the service that answered, for the caller to remember.
   */
  async send({ deviceToken, environment, payload, collapseID, pushType = "alert" }) {
    const first = environment === "development" ? "development" : "production";
    const second = first === "development" ? "production" : "development";
    let reply = await this.#post(first, { deviceToken, payload, collapseID, pushType });
    let answered = first;
    if (reply.reason === "BadDeviceToken") {
      const other = await this.#post(second, { deviceToken, payload, collapseID, pushType });
      if (other.status === 200 || other.reason !== "BadDeviceToken") {
        reply = other;
        answered = second;
      }
    }

    const { status, reason } = reply;
    if (status === 200) return { outcome: "sent", environment: answered, reason: "" };
    if (status === 410 || reason === "BadDeviceToken" || reason === "DeviceTokenNotForTopic") {
      return { outcome: "gone", environment: answered, reason: reason || String(status) };
    }
    throw new Error(`APNs ${status} ${reason}`);
  }

  async #post(environment, { deviceToken, payload, collapseID, pushType }) {
    const session = this.#session(environment);
    const headers = {
      ":method": "POST",
      ":path": `/3/device/${deviceToken}`,
      authorization: `bearer ${this.#bearer()}`,
      // A Live Activity push goes to its own topic, under the app's.
      "apns-topic": pushType === "liveactivity" ? `${this.#topic}.push-type.liveactivity` : this.#topic,
      "apns-push-type": pushType,
      "apns-priority": "10",
    };
    if (collapseID) headers["apns-collapse-id"] = collapseID;

    const { status, body } = await new Promise((resolve, reject) => {
      const request = session.request(headers);
      let status = 0;
      let body = "";
      request.setTimeout(10_000, () => request.close(http2.constants.NGHTTP2_CANCEL));
      request.on("response", (reply) => (status = reply[":status"]));
      request.on("data", (chunk) => (body += chunk));
      request.on("end", () => resolve({ status, body }));
      request.on("error", reject);
      request.end(JSON.stringify(payload));
    });
    return { status, reason: status === 200 ? "" : safeReason(body) };
  }

  /** Closes the connections to Apple. */
  close() {
    for (const session of this.#sessions.values()) session.close();
    this.#sessions.clear();
  }

  /** The signed token Apple asks for. One is good for an hour, and is reused for most of it. */
  #bearer() {
    const now = Math.floor(Date.now() / 1000);
    if (this.#token && now - this.#token.issued < 45 * 60) return this.#token.value;
    const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
    const unsigned = `${encode({ alg: "ES256", kid: this.#keyID })}.${encode({ iss: this.#teamID, iat: now })}`;
    const signature = sign("sha256", Buffer.from(unsigned), { key: this.#key, dsaEncoding: "ieee-p1363" });
    this.#token = { issued: now, value: `${unsigned}.${signature.toString("base64url")}` };
    return this.#token.value;
  }

  #session(environment) {
    const host = hosts[environment] ?? hosts.production;
    let session = this.#sessions.get(host);
    if (!session || session.closed || session.destroyed) {
      session = http2.connect(host);
      session.on("error", () => this.#sessions.delete(host));
      session.on("goaway", () => this.#sessions.delete(host));
      this.#sessions.set(host, session);
    }
    return session;
  }
}

function safeReason(body) {
  try {
    return JSON.parse(body).reason ?? "";
  } catch {
    return "";
  }
}

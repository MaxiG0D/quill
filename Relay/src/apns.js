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
   * Sends one notification. Resolves to "sent", or to "gone" when Apple says the device
   * token is no longer good and should be forgotten. Throws on anything else.
   */
  async send({ deviceToken, environment, payload, collapseID }) {
    const session = this.#session(environment);
    const headers = {
      ":method": "POST",
      ":path": `/3/device/${deviceToken}`,
      authorization: `bearer ${this.#bearer()}`,
      "apns-topic": this.#topic,
      "apns-push-type": "alert",
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

    if (status === 200) return "sent";
    const reason = safeReason(body);
    if (status === 410 || reason === "BadDeviceToken" || reason === "DeviceTokenNotForTopic") return "gone";
    throw new Error(`APNs ${status} ${reason}`);
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

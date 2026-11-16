import assert from "node:assert/strict";
import { afterEach, test } from "node:test";
import { Refused, Relay } from "../src/relay.js";

const config = { googleClientID: "client", topic: "projects/p/topics/gmail" };
const device = "ab".repeat(32);

/** Accounts kept in memory. */
class MemoryAccounts {
  data = new Map();
  async get(email) {
    return this.data.has(email) ? structuredClone(this.data.get(email)) : null;
  }
  async addDevice(email, { deviceToken, environment, platform, refreshToken }) {
    const account = this.data.get(email) ?? {};
    this.data.set(email, { ...account, refreshToken, devices: { ...account.devices, [deviceToken]: { environment, platform } } });
  }
  async removeDevice(email, deviceToken) {
    const account = this.data.get(email);
    if (!account) return 0;
    delete account.devices[deviceToken];
    return Object.keys(account.devices).length;
  }
  async update(email, fields) {
    this.data.set(email, { ...this.data.get(email), ...fields });
  }
  async remove(email) {
    this.data.delete(email);
  }
}

class RecordingAPNs {
  sent = [];
  outcome = "sent";
  async send(push) {
    this.sent.push(push);
    return this.outcome;
  }
}

/** Answers Google's endpoints from a table keyed by a fragment of the URL. */
function stubGoogle(replies) {
  const calls = [];
  globalThis.fetch = async (url, options = {}) => {
    const address = String(url);
    calls.push(`${options.method ?? "GET"} ${address}`);
    const key = Object.keys(replies).filter((fragment) => address.includes(fragment)).sort((a, b) => b.length - a.length)[0];
    const reply = key ? replies[key] : { status: 404, body: {} };
    return new Response(JSON.stringify(reply.body ?? reply), { status: reply.status ?? 200 });
  };
  return calls;
}

const realFetch = globalThis.fetch;
afterEach(() => {
  globalThis.fetch = realFetch;
});

const google = {
  "/tokeninfo": { aud: "client", email: "Max@Example.com" },
  "/token": { access_token: "access" },
  "/profile": { emailAddress: "max@example.com" },
  "/watch": { historyId: "100", expiration: String(Date.now() + 7 * 24 * 60 * 60 * 1000) },
  "/stop": {},
  "/labels/INBOX": { threadsUnread: 4 },
};

function message(id, labelIds) {
  return {
    id,
    threadId: `t-${id}`,
    labelIds,
    snippet: "Hello",
    payload: { headers: [{ name: "From", value: "Priya <priya@example.com>" }, { name: "Subject", value: "Lunch" }] },
  };
}

test("registering stores the device and starts a watch from the current history", async () => {
  stubGoogle(google);
  const accounts = new MemoryAccounts();
  const relay = new Relay({ config, accounts, apns: new RecordingAPNs() });
  await relay.register("bearer", { deviceToken: device.toUpperCase(), environment: "development", platform: "macos", refreshToken: "refresh" });

  const account = await accounts.get("max@example.com");
  assert.deepEqual(account.devices, { [device]: { environment: "development", platform: "macos" } });
  assert.equal(account.refreshToken, "refresh");
  assert.equal(account.historyId, "100");
});

test("registration is refused for another app's token or another account's refresh token", async () => {
  const relay = new Relay({ config, accounts: new MemoryAccounts(), apns: new RecordingAPNs() });
  const request = { deviceToken: device, refreshToken: "refresh" };

  stubGoogle({ ...google, "/tokeninfo": { aud: "someone-else", email: "max@example.com" } });
  await assert.rejects(relay.register("bearer", request), (error) => error instanceof Refused && error.status === 403);

  stubGoogle({ ...google, "/profile": { emailAddress: "other@example.com" } });
  await assert.rejects(relay.register("bearer", request), (error) => error instanceof Refused && error.status === 403);

  stubGoogle(google);
  await assert.rejects(relay.register(undefined, request), (error) => error.status === 401);
  await assert.rejects(relay.register("bearer", { deviceToken: "nope", refreshToken: "r" }), (error) => error.status === 400);
});

test("a mailbox change notifies every device about unread Inbox mail and moves history on", async () => {
  const calls = stubGoogle({
    ...google,
    "/history": {
      history: [
        { messagesAdded: [{ message: { id: "m1", labelIds: ["INBOX", "UNREAD"] } }] },
        { messagesAdded: [{ message: { id: "m2", labelIds: ["INBOX", "UNREAD"] } }] },
      ],
    },
    "/messages/m1": message("m1", ["INBOX", "UNREAD"]),
    // Read on another device before the relay got to it.
    "/messages/m2": message("m2", ["INBOX"]),
  });
  const accounts = new MemoryAccounts();
  const apns = new RecordingAPNs();
  const relay = new Relay({ config, accounts, apns });
  await relay.register("bearer", { deviceToken: device, environment: "production", platform: "ios", refreshToken: "refresh" });

  await relay.mailboxChanged({ emailAddress: "Max@Example.com", historyId: 150 });

  assert.equal(apns.sent.length, 1);
  assert.equal(apns.sent[0].deviceToken, device);
  assert.equal(apns.sent[0].collapseID, "m1");
  assert.equal(apns.sent[0].payload.aps.badge, 4);
  assert.equal(apns.sent[0].payload.aps["thread-id"], "t-m1");
  assert.equal((await accounts.get("max@example.com")).historyId, "150");
  assert.ok(calls.some((call) => call.includes("startHistoryId=100")));

  // A repeat of the same notice, as Pub/Sub may send, announces nothing more.
  await relay.mailboxChanged({ emailAddress: "max@example.com", historyId: 150 });
  assert.equal(apns.sent.length, 1);
});

test("a device Apple no longer knows is forgotten, and so is a signed-out account", async () => {
  stubGoogle({
    ...google,
    "/history": { history: [{ messagesAdded: [{ message: { id: "m1", labelIds: ["INBOX", "UNREAD"] } }] }] },
    "/messages/m1": message("m1", ["INBOX", "UNREAD"]),
  });
  const accounts = new MemoryAccounts();
  const apns = new RecordingAPNs();
  apns.outcome = "gone";
  const relay = new Relay({ config, accounts, apns });
  await relay.register("bearer", { deviceToken: device, refreshToken: "refresh" });
  await relay.mailboxChanged({ emailAddress: "max@example.com", historyId: 150 });
  assert.deepEqual((await accounts.get("max@example.com")).devices, {});

  await relay.register("bearer", { deviceToken: device, refreshToken: "refresh" });
  stubGoogle({ ...google, "/token": { status: 400, body: { error: "invalid_grant" } } });
  await relay.mailboxChanged({ emailAddress: "max@example.com", historyId: 200 });
  assert.equal(await accounts.get("max@example.com"), null);
});

test("unregistering the last device stops the watch and forgets the account", async () => {
  const calls = stubGoogle(google);
  const accounts = new MemoryAccounts();
  const relay = new Relay({ config, accounts, apns: new RecordingAPNs() });
  await relay.register("bearer", { deviceToken: device, refreshToken: "refresh" });
  await relay.unregister("bearer", { deviceToken: device });
  assert.equal(await accounts.get("max@example.com"), null);
  assert.ok(calls.some((call) => call.startsWith("POST") && call.endsWith("/stop")));
});

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
  async addDevice(email, { deviceToken, environment, platform, refreshToken, activityStartToken }) {
    const account = this.data.get(email) ?? {};
    const entry = { environment, platform, ...(activityStartToken && { activityStartToken }) };
    this.data.set(email, { ...account, refreshToken, devices: { ...account.devices, [deviceToken]: entry } });
  }
  async removeDevice(email, deviceToken) {
    const account = this.data.get(email);
    if (!account) return 0;
    delete account.devices[deviceToken];
    return Object.keys(account.devices).length;
  }
  async addActivity(email, { activityToken, deviceToken, code, environment }) {
    const account = this.data.get(email);
    account.activities = { ...account.activities, [activityToken]: { deviceToken, code, environment } };
  }
  async takeActivities(email, code) {
    const account = this.data.get(email);
    const taken = Object.entries(account?.activities ?? {}).filter(([, activity]) => activity.code === code);
    for (const [token] of taken) delete account.activities[token];
    return taken;
  }
  async setEnvironment(email, deviceToken, environment) {
    this.data.get(email).devices[deviceToken].environment = environment;
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
  environment;
  async send(push) {
    this.sent.push(push);
    return { outcome: this.outcome, environment: this.environment ?? push.environment, reason: "" };
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

test("a device found in Apple's other push service is remembered there", async () => {
  stubGoogle({
    ...google,
    "/history": { history: [{ messagesAdded: [{ message: { id: "m1", labelIds: ["INBOX", "UNREAD"] } }] }] },
    "/messages/m1": message("m1", ["INBOX", "UNREAD"]),
  });
  const accounts = new MemoryAccounts();
  const apns = new RecordingAPNs();
  apns.environment = "development";
  const relay = new Relay({ config, accounts, apns });
  await relay.register("bearer", { deviceToken: device, environment: "production", refreshToken: "refresh" });
  await relay.mailboxChanged({ emailAddress: "max@example.com", historyId: 150 });
  assert.equal((await accounts.get("max@example.com")).devices[device].environment, "development");
});

test("a test code reaches the caller's devices as an alert and a Live Activity", async () => {
  stubGoogle(google);
  const apns = new RecordingAPNs();
  const relay = new Relay({ config, accounts: new MemoryAccounts(), apns });
  await assert.rejects(relay.testCode("bearer"), (error) => error.status === 404);

  const start = "cd".repeat(32);
  await relay.register("bearer", { deviceToken: device, environment: "production", platform: "ios", refreshToken: "refresh", activityStartToken: start });
  await relay.testCode("bearer");

  // The alert carries Copy (iOS only allows the clipboard write from its long-press view),
  // and the Live Activity shows the code at a glance.
  assert.equal(apns.sent.length, 2);
  assert.equal(apns.sent[0].payload.aps.category, "SIGN_IN_CODE");
  assert.equal(apns.sent[1].pushType, "liveactivity");
  assert.equal(apns.sent[1].deviceToken, start);
  assert.equal(apns.sent[1].payload.aps["content-state"].code, apns.sent[0].payload.code);

  // One without gets the alert with Copy.
  const other = new RecordingAPNs();
  const plain = new Relay({ config, accounts: new MemoryAccounts(), apns: other });
  await plain.register("bearer", { deviceToken: device, environment: "production", platform: "ios", refreshToken: "refresh" });
  await plain.testCode("bearer");
  assert.equal(other.sent.length, 1);
  assert.equal(other.sent[0].payload.aps.category, "SIGN_IN_CODE");
});

test("copying a code ends its Live Activities on every device, and only that code's", async () => {
  stubGoogle(google);
  const apns = new RecordingAPNs();
  const accounts = new MemoryAccounts();
  const relay = new Relay({ config, accounts, apns });
  const duo = "ab".repeat(32);
  const pad = "ef".repeat(32);
  await relay.register("bearer", { deviceToken: duo, environment: "development", platform: "ios", refreshToken: "refresh" });
  await relay.register("bearer", { deviceToken: pad, environment: "production", platform: "ios", refreshToken: "refresh" });
  const one = "11".repeat(32);
  const two = "22".repeat(32);
  const other = "33".repeat(32);
  await relay.registerActivity("bearer", { deviceToken: duo, activityToken: one.toUpperCase(), code: "482913" });
  await relay.registerActivity("bearer", { deviceToken: pad, activityToken: two, code: "482913" });
  await relay.registerActivity("bearer", { deviceToken: pad, activityToken: other, code: "111111" });

  await relay.dismiss("bearer", { code: "482913" });

  assert.deepEqual(apns.sent.map((push) => [push.deviceToken, push.environment, push.pushType]), [
    [one, "development", "liveactivity"],
    [two, "production", "liveactivity"],
  ]);
  const { aps } = apns.sent[0].payload;
  assert.equal(aps.event, "end");
  assert.equal(aps["dismissal-date"], aps.timestamp);
  assert.equal(aps["content-state"].code, "482913");
  // The ended ones are forgotten, the other code's is kept.
  assert.deepEqual(Object.keys((await accounts.get("max@example.com")).activities), [other]);
  await relay.dismiss("bearer", { code: "482913" });
  assert.equal(apns.sent.length, 2);
});

test("a code's Live Activities end a minute after it arrives, whatever happens", async () => {
  stubGoogle(google);
  const apns = new RecordingAPNs();
  const accounts = new MemoryAccounts();
  const scheduled = [];
  const relay = new Relay({ config, accounts, apns, later: async (seconds, body) => scheduled.push([seconds, body]) });
  await relay.register("bearer", { deviceToken: device, environment: "production", platform: "ios", refreshToken: "refresh", activityStartToken: "cd".repeat(32) });
  await relay.testCode("bearer");

  // One end is scheduled for the code, however many devices show it.
  assert.equal(scheduled.length, 1);
  const [seconds, body] = scheduled[0];
  assert.equal(seconds, 60);
  assert.deepEqual(body, { email: "max@example.com", code: apns.sent[0].payload.code });

  const token = "11".repeat(32);
  await relay.registerActivity("bearer", { deviceToken: device, activityToken: token, code: body.code });
  apns.sent = [];
  await relay.expire(body);
  assert.deepEqual(apns.sent.map((push) => [push.deviceToken, push.pushType, push.payload.aps.event]), [[token, "liveactivity", "end"]]);
  await relay.expire({ email: "max@example.com", code: "nope" });
  assert.equal(apns.sent.length, 1);
});

test("an activity is accepted only from a registered device, with a token and a code", async () => {
  stubGoogle(google);
  const relay = new Relay({ config, accounts: new MemoryAccounts(), apns: new RecordingAPNs() });
  await relay.register("bearer", { deviceToken: device, environment: "production", platform: "ios", refreshToken: "refresh" });
  const token = "11".repeat(32);
  await assert.rejects(relay.registerActivity("bearer", { deviceToken: "cd".repeat(32), activityToken: token, code: "482913" }), (error) => error.status === 404);
  await assert.rejects(relay.registerActivity("bearer", { deviceToken: device, activityToken: "nope", code: "482913" }), (error) => error.status === 400);
  await assert.rejects(relay.registerActivity("bearer", { deviceToken: device, activityToken: token, code: "abc" }), (error) => error.status === 400);
  await assert.rejects(relay.dismiss("bearer", { code: "" }), (error) => error.status === 400);
  await assert.rejects(relay.dismiss(undefined, { code: "482913" }), (error) => error.status === 401);
});

test("an archive or delete wakes every device with a silent push", async () => {
  stubGoogle({
    ...google,
    "/history": { history: [{ labelsRemoved: [{ message: { id: "m1", labelIds: [] }, labelIds: ["INBOX"] }] }] },
  });
  const apns = new RecordingAPNs();
  const relay = new Relay({ config, accounts: new MemoryAccounts(), apns });
  await relay.register("bearer", { deviceToken: device, environment: "production", platform: "ios", refreshToken: "refresh" });
  await relay.mailboxChanged({ emailAddress: "max@example.com", historyId: 150 });

  assert.equal(apns.sent.length, 1);
  assert.equal(apns.sent[0].pushType, "background");
  assert.equal(apns.sent[0].priority, 5);
  assert.equal(apns.sent[0].payload.aps.alert, undefined);
  assert.equal(apns.sent[0].payload.aps["content-available"], 1);
});

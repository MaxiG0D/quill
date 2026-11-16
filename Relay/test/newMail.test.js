import assert from "node:assert/strict";
import { generateKeyPairSync, verify } from "node:crypto";
import { test } from "node:test";
import { addedToInbox, isWaiting, payload } from "../src/newMail.js";
import { decodeEntities, decodeHeader, senderName } from "../src/text.js";

test("history yields each message added to the Inbox once, oldest first", () => {
  const history = [
    { messagesAdded: [{ message: { id: "m1", labelIds: ["INBOX", "UNREAD"] } }] },
    { messagesAdded: [{ message: { id: "m2", labelIds: ["SENT"] } }, { message: { id: "m1", labelIds: ["INBOX"] } }] },
    { labelsAdded: [{ message: { id: "m9", labelIds: ["INBOX"] } }] },
    { messagesAdded: [{ message: { id: "m3", labelIds: ["INBOX", "UNREAD"] } }] },
  ];
  assert.deepEqual(addedToInbox(history), ["m1", "m3"]);
  assert.deepEqual(addedToInbox(undefined), []);
});

test("only unread Inbox mail from someone else is waiting", () => {
  assert.equal(isWaiting({ labelIds: ["INBOX", "UNREAD"] }), true);
  assert.equal(isWaiting({ labelIds: ["INBOX"] }), false);
  assert.equal(isWaiting({ labelIds: ["UNREAD"] }), false);
  assert.equal(isWaiting({ labelIds: ["INBOX", "UNREAD", "SENT"] }), false);
  assert.equal(isWaiting({}), false);
});

test("a payload shows the sender, subject and summary, and names the thread", () => {
  const message = {
    id: "m1",
    threadId: "t1",
    snippet: "The renewal is attached. Don&#39;t wait ",
    payload: {
      headers: [
        { name: "from", value: "=?UTF-8?B?SG9sbGlzIExpYnJhcnkg4oCUIE5ld3M=?= <news@hollis.example>" },
        { name: "Subject", value: "=?UTF-8?Q?Caf=C3=A9_hours?=" },
      ],
    },
  };
  assert.deepEqual(payload(message, 3), {
    aps: {
      alert: { title: "Hollis Library — News", subtitle: "Café hours", body: "The renewal is attached. Don't wait" },
      sound: "default",
      badge: 3,
      "thread-id": "t1",
      "content-available": 1,
    },
  });
});

test("sender names", () => {
  assert.equal(senderName('"Okafor, Dan" <dan@example.com>'), "Okafor, Dan");
  assert.equal(senderName("Priya Raman <priya@example.com>"), "Priya Raman");
  assert.equal(senderName("<priya@example.com>"), "priya@example.com");
  assert.equal(senderName("priya@example.com"), "priya@example.com");
  assert.equal(senderName(undefined), "");
});

test("text decoding", () => {
  assert.equal(decodeEntities("Fall hours &amp; events &#8212; &lt;soon&gt; &unknown;"), "Fall hours & events — <soon> &unknown;");
  assert.equal(decodeHeader("=?UTF-8?Q?Caf=C3=A9?= =?UTF-8?Q?_hours?="), "Café hours");
  assert.equal(decodeHeader("Plain subject"), "Plain subject");
});

test("the APNs token is a valid ES256 signature", async () => {
  const { APNs } = await import("../src/apns.js");
  const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
  const apns = new APNs({ key: privateKey.export({ type: "pkcs8", format: "pem" }), keyID: "KEY", teamID: "TEAM", topic: "t" });
  // The token is private to the class, so it is read back from a request to a local server.
  const http2 = await import("node:http2");
  const server = http2.createServer();
  const seen = new Promise((resolve) => {
    server.on("stream", (stream, headers) => {
      resolve(headers);
      stream.respond({ ":status": 410 });
      stream.end(JSON.stringify({ reason: "Unregistered" }));
    });
  });
  await new Promise((resolve) => server.listen(0, resolve));
  const original = http2.default.connect;
  http2.default.connect = () => original(`http://localhost:${server.address().port}`);
  try {
    const outcome = await apns.send({ deviceToken: "ab", environment: "development", payload: {}, collapseID: "m1" });
    assert.equal(outcome, "gone");
    const headers = await seen;
    assert.equal(headers["apns-collapse-id"], "m1");
    const [head, claims, signature] = headers.authorization.replace("bearer ", "").split(".");
    assert.deepEqual(JSON.parse(Buffer.from(head, "base64url")), { alg: "ES256", kid: "KEY" });
    assert.equal(JSON.parse(Buffer.from(claims, "base64url")).iss, "TEAM");
    const isValid = verify("sha256", Buffer.from(`${head}.${claims}`), { key: publicKey, dsaEncoding: "ieee-p1363" }, Buffer.from(signature, "base64url"));
    assert.equal(isValid, true);
  } finally {
    http2.default.connect = original;
    apns.close();
    server.close();
  }
});

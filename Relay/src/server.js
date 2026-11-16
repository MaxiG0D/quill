import { createServer } from "node:http";
import { OAuth2Client } from "google-auth-library";
import { Accounts } from "./accounts.js";
import { APNs } from "./apns.js";
import { loadConfig } from "./config.js";
import { SignedOut } from "./google.js";
import { Refused, Relay } from "./relay.js";

// Quill's push relay.
//
//   POST   /devices   Quill registers a device. Bearer: the account's Google access token.
//   DELETE /devices   Quill removes a device on sign-out.
//   POST   /gmail     Pub/Sub delivers Gmail's notice that a mailbox changed.

const config = loadConfig();
const relay = new Relay({ config, accounts: new Accounts(), apns: new APNs(config.apns) });
const verifier = new OAuth2Client();

function bearer(request) {
  const [scheme, token] = (request.headers.authorization ?? "").split(" ");
  return scheme?.toLowerCase() === "bearer" ? token : undefined;
}

async function body(request) {
  let text = "";
  for await (const chunk of request) {
    text += chunk;
    if (text.length > 100_000) throw new Refused(413, "Too large.");
  }
  try {
    return text ? JSON.parse(text) : {};
  } catch {
    throw new Refused(400, "Not JSON.");
  }
}

/** Checks that a delivery really comes from this project's Pub/Sub subscription. */
async function verifyPubSub(request) {
  try {
    const ticket = await verifier.verifyIdToken({ idToken: bearer(request) ?? "", audience: config.pubsubAudience });
    const claims = ticket.getPayload();
    if (claims?.email !== config.pubsubServiceAccount || !claims.email_verified) throw new Error();
  } catch {
    throw new Refused(403, "Not from Pub/Sub.");
  }
}

async function route(request) {
  const { pathname } = new URL(request.url, "http://relay");
  if (pathname === "/devices" && request.method === "POST") {
    await relay.register(bearer(request), await body(request));
    return 204;
  }
  if (pathname === "/devices" && request.method === "DELETE") {
    await relay.unregister(bearer(request), await body(request));
    return 204;
  }
  if (pathname === "/gmail" && request.method === "POST") {
    await verifyPubSub(request);
    const envelope = await body(request);
    let notice;
    try {
      notice = JSON.parse(Buffer.from(envelope.message?.data ?? "", "base64").toString());
    } catch {
      // Nothing a second delivery would fix, so it is acknowledged and dropped.
      return 204;
    }
    await relay.mailboxChanged(notice);
    return 204;
  }
  if (pathname === "/" && request.method === "GET") return 204;
  throw new Refused(404, "Not found.");
}

createServer(async (request, response) => {
  try {
    response.writeHead(await route(request)).end();
  } catch (error) {
    // A refusal is the caller's to fix. Anything else is answered with a 500, which
    // makes Pub/Sub deliver the notice again later.
    const status = error instanceof Refused ? error.status : error instanceof SignedOut ? 401 : 500;
    if (status === 500) console.error(error);
    else if (status >= 400) console.warn(`${request.method} ${request.url} refused ${status}: ${error.message || error.constructor.name}`);
    response.writeHead(status, { "content-type": "application/json" });
    response.end(JSON.stringify({ error: status === 500 ? "Something went wrong." : error.message }));
  }
}).listen(config.port, () => console.log(`Quill relay listening on ${config.port}`));

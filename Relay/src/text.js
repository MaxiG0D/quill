// Turning what Gmail returns into the words a notification shows.

const entities = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " " };

/** Gmail's snippet with its HTML entities decoded. */
export function decodeEntities(text) {
  return text
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCodePoint(parseInt(code, 16)))
    .replace(/&([a-z]+);/gi, (whole, name) => entities[name.toLowerCase()] ?? whole);
}

/** A header value with its RFC 2047 encoded words, such as =?UTF-8?B?…?=, decoded. */
export function decodeHeader(value) {
  return value
    // White space between two encoded words is not part of the text.
    .replace(/(\?=)\s+(=\?)/g, "$1$2")
    .replace(/=\?([^?]+)\?([bq])\?([^?]*)\?=/gi, (whole, charset, encoding, text) => {
      try {
        const bytes =
          encoding.toLowerCase() === "b"
            ? Buffer.from(text, "base64")
            : Buffer.from(
                text.replace(/_/g, " ").replace(/=([0-9a-f]{2})/gi, (_, hex) => String.fromCharCode(parseInt(hex, 16))),
                "latin1",
              );
        return new TextDecoder(charset).decode(bytes);
      } catch {
        return whole;
      }
    });
}

/** The name in a From header, or the address when there is no name. */
export function senderName(from) {
  const decoded = decodeHeader(from ?? "").trim();
  const match = decoded.match(/^(.*?)\s*<([^>]*)>$/);
  if (!match) return decoded;
  const name = match[1].replace(/^"(.*)"$/, "$1").replace(/\\(.)/g, "$1").trim();
  return name || match[2];
}

/** The lowercased address in a From header, or "" when there is none. */
export function senderAddress(from) {
  const decoded = decodeHeader(from ?? "").trim();
  const match = decoded.match(/<([^>]*)>\s*$/);
  const address = (match ? match[1] : decoded).trim().toLowerCase();
  return /^[^\s@<>]+@[^\s@<>]+$/.test(address) ? address : "";
}

export function header(message, name) {
  const found = message.payload?.headers?.find((item) => item.name.toLowerCase() === name.toLowerCase());
  return found?.value;
}

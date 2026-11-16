// Everything the relay is told about its surroundings, read once from the environment.
// deploy.sh sets all of it.

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing environment variable ${name}`);
  return value;
}

export function loadConfig() {
  return {
    port: Number(process.env.PORT ?? 8080),
    // Quill's iOS OAuth client. Only tokens issued to it may register a device.
    googleClientID: required("GOOGLE_CLIENT_ID"),
    // The Pub/Sub topic Gmail publishes to: projects/<project>/topics/<topic>.
    topic: required("GMAIL_TOPIC"),
    // The service account Pub/Sub signs its deliveries as, and the URL it delivers to.
    pubsubServiceAccount: required("PUBSUB_SERVICE_ACCOUNT"),
    pubsubAudience: required("PUBSUB_AUDIENCE"),
    apns: {
      key: required("APNS_KEY"),
      keyID: required("APNS_KEY_ID"),
      teamID: required("APNS_TEAM_ID"),
      topic: required("APNS_TOPIC"),
    },
  };
}

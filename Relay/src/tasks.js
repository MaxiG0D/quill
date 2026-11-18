import { GoogleAuth } from "google-auth-library";

/**
 * Asks Cloud Tasks to call the relay's /expire route after `seconds`, signed as the same
 * account Pub/Sub uses, so the relay checks both the same way. Cloud Run sleeps between
 * requests, so a timer inside the relay would not fire on time.
 */
export function cloudTasks({ queue, relayURL, serviceAccount, audience }) {
  const auth = new GoogleAuth({ scopes: ["https://www.googleapis.com/auth/cloud-platform"] });
  return async (seconds, body) => {
    const client = await auth.getClient();
    await client.request({
      url: `https://cloudtasks.googleapis.com/v2/${queue}/tasks`,
      method: "POST",
      data: {
        task: {
          scheduleTime: new Date(Date.now() + seconds * 1000).toISOString(),
          httpRequest: {
            httpMethod: "POST",
            url: `${relayURL}/expire`,
            headers: { "Content-Type": "application/json" },
            body: Buffer.from(JSON.stringify(body)).toString("base64"),
            oidcToken: { serviceAccountEmail: serviceAccount, audience },
          },
        },
      },
    });
  };
}

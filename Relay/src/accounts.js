import { Firestore, FieldValue } from "@google-cloud/firestore";

/**
 * What the relay remembers about each Gmail account, one Firestore document per address:
 * the refresh token it reads mail with, where it is in the mailbox's history, when the
 * Gmail watch runs out, and the devices to notify.
 */
export class Accounts {
  #collection;

  constructor(firestore = new Firestore({ ignoreUndefinedProperties: true })) {
    this.#collection = firestore.collection("accounts");
  }

  async get(email) {
    const snapshot = await this.#collection.doc(email).get();
    return snapshot.exists ? snapshot.data() : null;
  }

  /** Adds or refreshes a device, and takes the newest refresh token. */
  async addDevice(email, { deviceToken, environment, platform, refreshToken, activityStartToken, allInbox = false }) {
    await this.#collection.doc(email).set(
      {
        refreshToken,
        devices: {
          [deviceToken]: { environment, platform, allInbox, activityStartToken: activityStartToken ?? FieldValue.delete(), updatedAt: FieldValue.serverTimestamp() },
        },
      },
      { merge: true },
    );
  }

  /** How long a Live Activity's token is kept, in milliseconds. A code is stale long before. */
  static activityLife = 30 * 60 * 1000;

  /** Remembers a Live Activity's update token, and drops the ones too old to matter. */
  async addActivity(email, { activityToken, deviceToken, code, environment }) {
    const reference = this.#collection.doc(email);
    const now = Date.now();
    await reference.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      const activities = snapshot.exists ? (snapshot.data().activities ?? {}) : {};
      for (const [token, activity] of Object.entries(activities)) {
        if (now - Number(activity.createdAt ?? 0) > Accounts.activityLife) delete activities[token];
      }
      activities[activityToken] = { deviceToken, code, environment, createdAt: now };
      transaction.set(reference, { activities }, { merge: true });
    });
  }

  /** Removes the Live Activities showing `code` and returns them, as `[token, activity]` pairs. */
  async takeActivities(email, code) {
    const reference = this.#collection.doc(email);
    return reference.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) return [];
      const activities = snapshot.data().activities ?? {};
      const taken = Object.entries(activities).filter(([, activity]) => activity.code === code);
      if (!taken.length) return [];
      for (const [token] of taken) delete activities[token];
      transaction.update(reference, { activities });
      return taken;
    });
  }

  /** Corrects which of Apple's push services a device's token belongs to. */
  async setEnvironment(email, deviceToken, environment) {
    await this.#collection.doc(email).set({ devices: { [deviceToken]: { environment } } }, { merge: true });
  }

  /** Forgets a device's Live Activity token, once Apple says it no longer works. */
  async clearActivityStartToken(email, deviceToken) {
    await this.#collection
      .doc(email)
      .set({ devices: { [deviceToken]: { activityStartToken: FieldValue.delete() } } }, { merge: true });
  }

  /** Removes a device. Resolves to how many the account has left. */
  async removeDevice(email, deviceToken) {
    const reference = this.#collection.doc(email);
    return reference.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) return 0;
      const devices = snapshot.data().devices ?? {};
      delete devices[deviceToken];
      transaction.update(reference, { devices });
      return Object.keys(devices).length;
    });
  }

  async update(email, fields) {
    await this.#collection.doc(email).set(fields, { merge: true });
  }

  async remove(email) {
    await this.#collection.doc(email).delete();
  }
}

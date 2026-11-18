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
  async addDevice(email, { deviceToken, environment, platform, refreshToken, activityStartToken }) {
    await this.#collection.doc(email).set(
      {
        refreshToken,
        devices: {
          [deviceToken]: { environment, platform, activityStartToken: activityStartToken ?? FieldValue.delete(), updatedAt: FieldValue.serverTimestamp() },
        },
      },
      { merge: true },
    );
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

/**
 * Doodh Hisab — change history and push notifications.
 *
 * Two jobs, both triggered by writes to Firestore:
 *
 *   1. Append an entry to /activity describing exactly what changed.
 *   2. Push a notification to the owner's phone(s).
 *
 * Both run on the server for the same reason: the history must record what
 * happened to the data, so it cannot depend on the app choosing to report it.
 * A modified APK still trips these triggers.
 */

const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// Mumbai — same region as Firestore, so the trigger fires without a
// cross-region hop. maxInstances caps runaway cost: a 50-house dairy needs
// nowhere near this, and it makes an accidental loop bounded rather than open.
setGlobalOptions({ region: 'asia-south1', maxInstances: 10 });

const DAIRY = 'main';

/** `2` / `2.5` — never `2.0`, which reads as clutter in a notification. */
function litres(value) {
  if (value === null || value === undefined) return '0';
  const s = Number(value).toFixed(1);
  return s.endsWith('.0') ? s.slice(0, -2) : s;
}

/**
 * Customer name for display, falling back to the ID.
 *
 * Denormalised into the activity entry rather than joined at read time, so the
 * history still reads correctly after a customer is renamed or deactivated.
 */
async function customerName(dairyId, customerId) {
  if (!customerId) return null;
  try {
    const snap = await db
      .doc(`dairies/${dairyId}/customers/${customerId}`)
      .get();
    return snap.exists ? snap.data().name || customerId : customerId;
  } catch (err) {
    console.error('customerName lookup failed', err);
    return customerId;
  }
}

/** Write one history entry. */
async function recordActivity(dairyId, entry) {
  await db.collection(`dairies/${dairyId}/activity`).add({
    ...entry,
    at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Send a push to every device the owner has registered.
 *
 * Tokens go stale when an app is reinstalled or sits unused for months; a send
 * to a dead token fails permanently, so those are pruned here rather than
 * accumulating and slowing every later send.
 */
async function pushToOwners(dairyId, title, body, data = {}) {
  const tokensSnap = await db
    .collection(`dairies/${dairyId}/ownerTokens`)
    .get();

  const tokens = tokensSnap.docs.map((d) => d.id);
  if (tokens.length === 0) {
    console.log('no owner tokens registered; skipping push');
    return;
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)])
    ),
    android: {
      priority: 'high',
      notification: { channelId: 'doodh_updates', sound: 'default' },
    },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  });

  const dead = [];
  response.responses.forEach((r, i) => {
    if (r.success) return;
    const code = r.error && r.error.code;
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token'
    ) {
      dead.push(tokens[i]);
    } else {
      console.error('push failed', code, r.error && r.error.message);
    }
  });

  await Promise.all(
    dead.map((t) =>
      db.doc(`dairies/${dairyId}/ownerTokens/${t}`).delete().catch(() => {})
    )
  );
}

/**
 * Decide what a delivery write actually means.
 *
 * Split out and exported so the tests exercise this exact function rather than
 * a copy that can drift away from it.
 *
 *   'recorded' — first time this house/day was written
 *   'edited'   — the litres or the delivered/skipped status changed
 *   'ignore'   — nothing meaningful changed
 *   'removed'  — the document is gone
 */
function classifyDeliveryChange(before, after) {
  if (!after) return before ? 'removed' : 'none';
  const isEdit =
    before !== null &&
    (before.qtyLitres !== after.qtyLitres || before.status !== after.status);
  if (before !== null && !isEdit) return 'ignore';
  return isEdit ? 'edited' : 'recorded';
}

/**
 * Deliveries: the main event.
 *
 * A first record and a later correction are deliberately reported differently.
 * "Ram — 2 L" is routine; "Ram — changed from 2 L to 3 L" is the thing the
 * owner actually wants to be told about, which is what was asked for.
 */
exports.onDeliveryWritten = onDocumentWritten(
  'dairies/{dairyId}/deliveries/{deliveryId}',
  async (event) => {
    const { dairyId } = event.params;
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;

    // Deletes are denied by the security rules, but handle it rather than
    // crashing if one ever arrives through the console.
    if (!after) {
      if (!before) return;
      const name = await customerName(dairyId, before.customerId);
      await recordActivity(dairyId, {
        type: 'delivery_removed',
        actorEmail: 'unknown',
        customerId: before.customerId,
        customerName: name,
        dayKey: before.dayKey,
        beforeLitres: before.qtyLitres ?? 0,
        beforeStatus: before.status ?? null,
      });
      await pushToOwners(
        dairyId,
        'Entry deleted',
        `${name} — ${before.dayKey} entry was removed`,
        { customerId: before.customerId || '' }
      );
      return;
    }

    const name = await customerName(dairyId, after.customerId);
    const actor = after.editedBy || after.recordedBy || 'unknown';
    const change = classifyDeliveryChange(before, after);

    // A write that changed nothing meaningful — a re-sync of the same offline
    // entry, say — must not fire a notification, or a patchy signal would
    // buzz the owner's phone repeatedly for one delivery.
    if (change === 'ignore') return;

    if (change === 'edited') {
      await recordActivity(dairyId, {
        type: 'delivery_edited',
        actorEmail: actor,
        customerId: after.customerId,
        customerName: name,
        dayKey: after.dayKey,
        beforeLitres: before.qtyLitres ?? 0,
        afterLitres: after.qtyLitres ?? 0,
        beforeStatus: before.status ?? null,
        afterStatus: after.status ?? null,
        reason: after.editReason || null,
      });

      const wasSkipped = before.status === 'skipped';
      const nowSkipped = after.status === 'skipped';
      const description = nowSkipped
        ? `changed to "not taken" (was ${litres(before.qtyLitres)} L)`
        : wasSkipped
          ? `changed from "not taken" to ${litres(after.qtyLitres)} L`
          : `changed from ${litres(before.qtyLitres)} L to ${litres(after.qtyLitres)} L`;

      await pushToOwners(
        dairyId,
        `Changed: ${name}`,
        `${after.dayKey} — ${description}${after.editReason ? ` · ${after.editReason}` : ''}`,
        { customerId: after.customerId || '', dayKey: after.dayKey || '' }
      );
      return;
    }

    await recordActivity(dairyId, {
      type: 'delivery_recorded',
      actorEmail: actor,
      customerId: after.customerId,
      customerName: name,
      dayKey: after.dayKey,
      afterLitres: after.qtyLitres ?? 0,
      afterStatus: after.status ?? null,
    });

    await pushToOwners(
      dairyId,
      name,
      after.status === 'skipped'
        ? 'Not taken today'
        : `${litres(after.qtyLitres)} L delivered`,
      { customerId: after.customerId || '', dayKey: after.dayKey || '' }
    );
  }
);

/**
 * Payments: cash the delivery person logged at the door, plus the owner's own
 * approvals. Approving is worth a history entry because it is the moment an
 * unverified claim becomes a real reduction in someone's balance.
 */
exports.onPaymentWritten = onDocumentWritten(
  'dairies/{dairyId}/payments/{paymentId}',
  async (event) => {
    const { dairyId } = event.params;
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (!after) return;

    const name = await customerName(dairyId, after.customerId);

    if (before === null) {
      await recordActivity(dairyId, {
        type: 'payment_logged',
        actorEmail: after.recordedBy || 'unknown',
        customerId: after.customerId,
        customerName: name,
        dayKey: after.dayKey,
        amount: after.amount ?? 0,
      });

      // Only an unapproved entry needs the owner's attention; one the owner
      // just recorded themselves does not need to notify them about it.
      if (after.approved !== true) {
        await pushToOwners(
          dairyId,
          `Cash collected: ${name}`,
          `₹${after.amount} — waiting for your approval`,
          { customerId: after.customerId || '' }
        );
      }
      return;
    }

    if (before.approved !== true && after.approved === true) {
      await recordActivity(dairyId, {
        type: 'payment_approved',
        actorEmail: after.approvedBy || 'unknown',
        customerId: after.customerId,
        customerName: name,
        dayKey: after.dayKey,
        amount: after.amount ?? 0,
      });
    }
  }
);

/**
 * Customer edits. No push — the owner is the only one who can make these, so
 * notifying them of their own action would be noise. The history entry still
 * matters: a changed usual-quantity or rate affects what the numbers mean.
 */
exports.onCustomerWritten = onDocumentWritten(
  'dairies/{dairyId}/customers/{customerId}',
  async (event) => {
    const { dairyId, customerId } = event.params;
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (!after || before === null) return;

    const changed =
      before.defaultQtyLitres !== after.defaultQtyLitres ||
      before.active !== after.active ||
      before.name !== after.name;
    if (!changed) return;

    await recordActivity(dairyId, {
      type: 'customer_changed',
      actorEmail: 'owner',
      customerId,
      customerName: after.name || customerId,
      beforeLitres: before.defaultQtyLitres ?? null,
      afterLitres: after.defaultQtyLitres ?? null,
      reason:
        before.active !== after.active
          ? after.active
            ? 'reactivated'
            : 'deactivated'
          : null,
    });
  }
);

// Exported for the unit tests. Not part of the deployed trigger surface —
// Firebase only treats onDocument* exports as functions.
exports._internal = { classifyDeliveryChange, litres };

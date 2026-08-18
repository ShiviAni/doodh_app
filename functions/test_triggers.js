/**
 * Behavioural checks on the trigger decision logic.
 *
 * These import the real functions from index.js rather than reimplementing
 * them, so the tests cannot quietly drift away from what actually deploys.
 * The branches here are where a bug is silent and expensive: a wrong answer
 * means either a missed notification or a phone that buzzes repeatedly for a
 * single delivery.
 */
const assert = require('node:assert');
const { test } = require('node:test');

process.env.GCLOUD_PROJECT ??= 'doodh-test';
process.env.FIREBASE_CONFIG ??= JSON.stringify({ projectId: 'doodh-test' });

const { classifyDeliveryChange, litres } = require('./index.js')._internal;

const d = (qtyLitres, status = 'delivered') => ({ qtyLitres, status });

test('a brand new entry is a record', () => {
  assert.strictEqual(classifyDeliveryChange(null, d(2)), 'recorded');
});

test('changing the quantity is an edit', () => {
  assert.strictEqual(classifyDeliveryChange(d(2), d(3)), 'edited');
});

test('changing delivered to skipped is an edit', () => {
  assert.strictEqual(classifyDeliveryChange(d(2), d(0, 'skipped')), 'edited');
});

test('changing skipped back to delivered is an edit', () => {
  assert.strictEqual(classifyDeliveryChange(d(0, 'skipped'), d(2)), 'edited');
});

test('an identical re-write is ignored', () => {
  // The important one. Firestore replays a queued offline write when signal
  // returns, and a flaky connection can do it more than once. Without this
  // branch the owner's phone buzzes repeatedly for a single delivery.
  assert.strictEqual(classifyDeliveryChange(d(2), d(2)), 'ignore');
});

test('a metadata-only change does not count as an edit', () => {
  // The server timestamp resolving, or recordedBy being filled in: the milk
  // figures are untouched, so the owner does not need telling.
  const before = { qtyLitres: 2, status: 'delivered', recordedBy: null };
  const after = { qtyLitres: 2, status: 'delivered', recordedBy: 'boy@x.com' };
  assert.strictEqual(classifyDeliveryChange(before, after), 'ignore');
});

test('a delete is reported as removed', () => {
  assert.strictEqual(classifyDeliveryChange(d(2), null), 'removed');
});

test('a half-litre correction is caught, not rounded away', () => {
  // 2 to 2.5 is the most common real correction and the easiest to lose to a
  // sloppy equality check.
  assert.strictEqual(classifyDeliveryChange(d(2), d(2.5)), 'edited');
});

test('litres formatting drops a trailing zero but keeps a half', () => {
  assert.strictEqual(litres(2), '2');
  assert.strictEqual(litres(2.5), '2.5');
  assert.strictEqual(litres(0.5), '0.5');
  assert.strictEqual(litres(null), '0');
  assert.strictEqual(litres(undefined), '0');
});

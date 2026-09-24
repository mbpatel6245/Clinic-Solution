const {test, beforeEach, after} = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {enqueueEvent, createNotificationHandlers} = require('../lib/event_notifications.js');
const {ProviderError} = require('../lib/notification_provider.js');
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(localhost|127\.0\.0\.1):\d+$/.test(host)) throw new Error('Run only against a local Firestore emulator');
const app = initializeApp({projectId: 'demo-clinic-templates'});
const db = getFirestore();
const outbox = db.collection('notification_outbox');
const recipient = {email: 'patient@example.com', phone: '+919876543210', name: 'Asha', clinic: 'Test Clinic', variables: {action_url: 'https://example.com/test-token'}};
const tick = (handlers) => handlers.dispatchEventNotifications.run({scheduleTime: new Date().toISOString()});
beforeEach(async () => {
  const docs = await outbox.get();
  const batch = db.batch();
  for (const doc of docs.docs) batch.delete(doc.ref);
  await batch.commit();
});
after(() => deleteApp(app));

test('event redelivery and overlapping workers send each channel once', async () => {
  await enqueueEvent('same-event', 'password_reset', recipient);
  await enqueueEvent('same-event', 'password_reset', recipient);
  assert.equal((await outbox.get()).size, 2);
  const sent = [];
  const handlers = createNotificationHandlers(async (job) => {
    sent.push(job);
    return {provider: 'twilio', messageId: 'fake-message', acceptedStatus: 'accepted'};
  }, []);
  await Promise.all([tick(handlers), tick(handlers)]);
  assert.equal(sent.length, 2);
  assert.deepEqual(new Set(sent.map((job) => job.channel)), new Set(['sms', 'email']));
  for (const doc of (await outbox.get()).docs) {
    assert.equal(doc.data().status, 'sent');
    assert.equal(doc.data().attempts, 1);
    assert.equal(doc.data().job, undefined, 'secret payload is removed after delivery');
  }
  await tick(handlers);
  assert.equal(sent.length, 2);
});

test('retryable failure backs off and stops at three attempts without retaining reset links', async () => {
  await enqueueEvent('retry-event', 'password_reset', {...recipient, phone: ''});
  let calls = 0;
  const handlers = createNotificationHandlers(async () => { calls++; throw new ProviderError('provider echoed SECRET', true); }, []);
  await tick(handlers);
  let doc = (await outbox.get()).docs[0];
  assert.equal(doc.data().status, 'retry');
  assert.ok(doc.data().next_attempt_at.toMillis() > Date.now());
  assert.equal(doc.data().error.includes('SECRET'), false);
  await tick(handlers);
  assert.equal(calls, 1, 'not retried before its due time');
  for (let attempt = 2; attempt <= 3; attempt++) {
    await doc.ref.update({next_attempt_at: Timestamp.fromMillis(0)});
    await tick(handlers);
  }
  doc = await doc.ref.get();
  assert.equal(doc.data().status, 'failed');
  assert.equal(doc.data().attempts, 3);
  assert.equal(doc.data().job, undefined);
  await tick(handlers);
  assert.equal(calls, 3);
});

test('disabled channels and permanent failures do not retry', async () => {
  await enqueueEvent('skip-event', 'account_created', recipient);
  const handlers = createNotificationHandlers(async (job) => {
    if (job.channel === 'sms') throw new ProviderError('invalid recipient', false);
    return {provider: 'twilio', messageId: '', acceptedStatus: 'disabled'};
  }, []);
  await tick(handlers);
  const rows = (await outbox.get()).docs.map((doc) => doc.data());
  assert.deepEqual(new Set(rows.map((row) => row.status)), new Set(['failed', 'skipped']));
  assert.ok(rows.every((row) => row.job === undefined && row.attempts === 1));
});

test('appointment hook respects consent, ignores notes, and queues a reschedule in both channels', async () => {
  await db.doc('clinics/test-clinic').set({name: 'Test Clinic', timezone: 'Asia/Kolkata'});
  const handlers = createNotificationHandlers(async () => { throw new Error('should not send directly'); }, []);
  const initial = {patient_name: 'Asha', email: recipient.email, phone: recipient.phone, scheduled_at: Timestamp.fromMillis(1800000000000), status: 'booked'};
  const fire = (id, before, after) => handlers.notifyAppointmentChanged.run({id,
    params: {clinicId: 'test-clinic', appointmentId: 'appointment-1'},
    data: {before: {data: () => before}, after: {data: () => after}}});
  await fire('no-consent', undefined, initial);
  assert.equal((await outbox.get()).size, 0);
  const consented = {...initial, notification_consent: true};
  await fire('notes', consented, {...consented, notes: 'changed'});
  assert.equal((await outbox.get()).size, 0);
  await fire('reschedule', consented, {...consented, scheduled_at: Timestamp.fromMillis(1800003600000)});
  const rows = (await outbox.get()).docs.map((doc) => doc.data());
  assert.equal(rows.length, 2);
  assert.ok(rows.every((row) => row.job.event === 'appointment_rescheduled'));
  assert.match(rows[0].job.templateVariables.appointment_at, /Asia\/Kolkata/);
});

const {test, before} = require('node:test');
const assert = require('node:assert/strict');
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(localhost|127\.0\.0\.1):\d+$/.test(host)) throw new Error('Run only against a local Firestore emulator');
const project = 'demo-clinic-templates';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const document = (path) => `projects/${project}/databases/(default)/documents/${path}`;
function token(uid) {
  const encode = (data) => Buffer.from(JSON.stringify(data)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  return `${encode({alg: 'none', typ: 'JWT'})}.${encode({aud: project, iss: `https://securetoken.google.com/${project}`, sub: uid, user_id: uid, iat: now, exp: now + 3600, firebase: {sign_in_provider: 'custom', identities: {}}})}.`;
}
function fields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, value]) => [key,
    typeof value === 'boolean' ? {booleanValue: value} : typeof value === 'number' ? {integerValue: String(value)} : {stringValue: value}]));
}
async function commit(writes, auth = token('owner')) {
  return fetch(`${base}:commit`, {method: 'POST', headers: {'content-type': 'application/json', ...(auth ? {authorization: `Bearer ${auth}`} : {})}, body: JSON.stringify({writes})});
}
function templateWrite(event, channel, revision = 1, extras = {}) {
  return {update: {name: document(`notification_templates/${event}_${channel}_en`), fields: fields({event, channel, locale: 'en', enabled: true, subject: channel === 'email' ? 'Subject' : '', body: 'Hello {{patient_name}} {{action_url}}', msg91_template_id: '', twilio_template_id: '', revision, updated_by: 'owner', ...extras})}, updateTransforms: [{fieldPath: 'updated_at', setToServerValue: 'REQUEST_TIME'}]};
}
before(async () => {
  const templateIds = ['account_created_email_en', 'account_created_sms_en', 'account_pending_sms_en', 'password_reset_email_en', 'account_approved_email_en'];
  const cleanup = await commit(templateIds.flatMap((id) => [
    {delete: document(`notification_templates/${id}/history/1`)},
    {delete: document(`notification_templates/${id}`)},
  ]), 'owner');
  assert.equal(cleanup.status, 200, await cleanup.text());
  const result = await commit(['owner', 'admin', 'patient'].map((uid) => ({update: {name: document(`users/${uid}`), fields: fields({role: uid === 'owner' ? 'platform_owner' : uid === 'admin' ? 'clinic_admin' : 'patient'})}})), 'owner');
  assert.equal(result.status, 200, await result.text());
});
test('owner can create and revise templates; stale revisions are rejected', async () => {
  assert.equal((await commit([templateWrite('account_created', 'email')])).status, 200);
  assert.equal((await commit([templateWrite('account_created', 'email', 2)])).status, 200);
  assert.equal((await commit([templateWrite('account_created', 'email', 2)])).status, 403);
});
test('clinic admins, patients and anonymous callers cannot edit global templates', async () => {
  for (const auth of [token('admin'), token('patient'), '']) {
    assert.equal((await commit([templateWrite('account_created', 'sms')], auth)).status, 403);
  }
});
test('reset email cannot be disabled and oversized SMS is rejected', async () => {
  assert.equal((await commit([templateWrite('password_reset', 'email', 1, {enabled: false})])).status, 403);
  assert.equal((await commit([templateWrite('account_pending', 'sms', 1, {body: 'x'.repeat(1601)})])).status, 403);
});
test('history is created atomically with the saved revision and is immutable', async () => {
  const write = templateWrite('account_approved', 'email');
  const history = {...write, update: {...write.update, name: `${write.update.name}/history/1`}};
  assert.equal((await commit([write, history])).status, 200);
  assert.equal((await commit([history])).status, 403);
});
test('outbox and password-reset rate limits are server-only even for the owner', async () => {
  for (const collection of ['notification_outbox', 'notification_rate_limits']) {
    const path = `${collection}/private`;
    assert.equal((await commit([{update: {name: document(path), fields: fields({secret: 'test'})}}])).status, 403);
    const response = await fetch(`${base}/${path}`, {headers: {authorization: `Bearer ${token('owner')}`}});
    assert.equal(response.status, 403);
  }
});

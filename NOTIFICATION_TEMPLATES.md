# Editable SMS and email templates

Product Owners (the existing **Platform Owner** role) open **Clinic setup → SMS & email templates → Manage message templates**. Select English, Hindi or Gujarati, then edit the SMS or email for an event. The editor provides placeholder insertion, sample previews, channel enable/disable controls, provider mappings and a default-text reset. Saving writes a revision and immutable history entry. Concurrent edits are rejected rather than silently overwriting another owner's work.

## Included events

| Area | Events | Delivery trigger |
| --- | --- | --- |
| Accounts | Password reset, account created, approval pending, approved | Reset request; user profile creation or approval |
| Team | Invitation, invitation approved | Invite creation/resend; approval |
| Appointments | Booked, confirmed, rescheduled, cancelled, completed | Appointment creation or relevant change, with notification consent |
| Reminders | Appointment, vaccination, follow-up, general | Existing scheduled reminder dispatcher |
| Billing | Invoice created, payment received | Invoice creation/payment increase, for a linked patient with clinic notification consent |

There are 17 event definitions and 34 English defaults in `functions/src/template_catalog.json`. Flutter loads the same catalog as an asset, avoiding differences between editor defaults and delivery. Hindi/Gujarati variants can be saved in the editor; until then, delivery uses the saved English version or the bundled English default. This feature does not automatically translate content. The app's selected language is stored with new accounts, invitations and appointments.

Appointment booking has an optional email and a separate appointment-update consent checkbox. Reception registration captures optional email and consent for appointment and billing updates. Old records do not receive new automatic appointment/billing notifications until consent is recorded. Billing also needs a linked patient ID. Empty contact channels are skipped. Existing scheduled reminders retain their existing consent requirement; use type `appointment`, `vaccination`, `follow_up`, or another type for the general reminder template.

Invitations email a Firebase password setup/reset link. Resending no longer changes an existing account's password. The optional invitation SMS links to `CLINIC_APP_URL` (defaults to the existing production site, `https://clinic.orbyteza.com`), never to an account reset token. Password reset SMS is only eligible when Firebase Auth has a verified `phoneNumber`; an ordinary profile phone is insufficient. Reset email is always enabled.

## Provider setup

Existing global provider configuration and Secret Manager credentials are reused. Configure primary and fallback providers in **Clinic setup → Global notifications**.

- **Twilio SMS:** blank event Content SID sends the rendered message as `Body`. A supplied Content SID uses variables `1` (name), `2` (clinic), and `3` (rendered message).
- **SendGrid email:** blank event template ID sends the edited subject and plain-text body directly, even when a global legacy template ID is configured. A supplied dynamic template ID must render `subject` and `message` variables. Keep a verified sender and API key configured.
- **MSG91 SMS/email:** set event-specific approved template IDs, or use matching global defaults. The adapter supplies `patient_name`, `clinic_name`, `message`, `subject` and the event variables. Provider templates must render these variables; editing app text cannot rewrite a provider's fixed content. Keep SMS content and language consistent with the provider-approved template. Template IDs are mapped independently for each provider, so fallback never reuses another provider's ID.
- **WhatsApp:** its existing provider-template workflow is unchanged by this SMS/email editor.

Provider references: [MSG91 email API](https://docs.msg91.com/email/send-email), [SendGrid mail send](https://www.twilio.com/docs/sendgrid/api-reference/mail-send/mail-send), [Firebase custom email action links](https://firebase.google.com/docs/auth/admin/email-action-links).

## Deploy before releasing the updated app

These source changes are not a deployment. Deploy the backend and rules before releasing the Flutter app: its password-reset screen now calls `requestPasswordReset` in `asia-south1`.

```powershell
cd functions
npm test
cd ..
firebase deploy --only firestore:rules,firestore:indexes,functions
flutter build web
```

Use your existing hosting/mobile release workflow for the built app. Verify the sender domains, provider credentials and template mappings with test recipients before rollout. No real SMS or email is sent by the automated tests.

The new event dispatcher runs every minute and uses deterministic event/channel job IDs, transactional leases and at most three attempts. Delivery is at least once: an ambiguous provider timeout can still cause a duplicate. Template changes apply when pending jobs are delivered. Disabling a channel skips its pending jobs. The existing invitation flow reports email and SMS delivery states on the invitation document. `sent` means the provider accepted the request, not confirmed handset/inbox delivery.

Template documents and immutable history are owner-only. Outbox payloads and rate-limit records deny all client access, including owners. Payloads containing reset links are removed after success, disablement or terminal failure. Reset requests return the same success response for unknown addresses and throttled requests; rate limits use hashed keys, a one-minute email cooldown, five requests per email/hour and twenty per IP/hour. Deploy the TTL field policy for `notification_rate_limits.expires_at` included in `firestore.indexes.json`.

## Local checks

Use Node.js 22 or later for the backend tests, matching the deployed Functions runtime.

```powershell
flutter test
npm --prefix functions test
firebase emulators:exec --config firebase.test.json --only firestore --project demo-clinic-templates "node --test functions/tests/template_rules.test.cjs functions/tests/notification_delivery.test.cjs"
```

The emulator tests use a local demo project. They verify owner access, revision conflicts, immutable history, disabled-reset protection, size limits, private queue access, event deduplication, overlapping workers, retry backoff, payload removal and appointment consent. The Flutter tests load the bundled Noto fonts and exercise Hindi/Gujarati form controls at 200% text scaling, including validation messages.

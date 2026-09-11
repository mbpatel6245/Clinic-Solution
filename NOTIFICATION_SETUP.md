# MSG91 notification setup

Last verified: **11 September 2026**

The clinic platform sends scheduled email, SMS, and WhatsApp reminders from
Firebase Functions through MSG91. The retired Firebase Trigger Email extension
is not used. Provider keys never enter Flutter, Firestore, source control, or a
browser bundle.

## Why MSG91 is the default

For an India-first clinic product, MSG91 is currently the more economical
single-provider choice:

| Channel | Current entry pricing | Notes |
| --- | --- | --- |
| Email | ₹0/month for 5,000 emails/month | No extra email sends on the free tier |
| India SMS | ₹0.25 each at 5,000; lower at volume | Requires Indian DLT registration |
| WhatsApp | MSG91 subscription plus Meta message fees | Approved templates and patient opt-in required |

By comparison, Twilio currently lists India outbound SMS at **US$0.0832 per
segment**, before possible extras. Prices change, so confirm the live pages
before purchasing: [MSG91 email pricing](https://msg91.com/in/pricing/email),
[MSG91 SMS pricing](https://msg91.com/in/pricing/sms), and
[Twilio India SMS pricing](https://www.twilio.com/en-us/sms/pricing/in).

The integration is isolated in `functions/src/msg91.ts`, so another provider
can be added later without putting provider code in the Flutter app.

## What is already implemented

- Firebase Functions Gen 2 on the supported Node.js 22 runtime.
- A scheduler that runs every minute in `asia-south1` / `Asia/Kolkata`.
- Atomic claiming, a five-minute lease, a maximum of three attempts, and
  exponential retry for timeouts, HTTP 429, and server errors.
- MSG91 Flow SMS, template email, and approved-template WhatsApp calls.
- A protected delivery webhook and an authenticated admin-only test function.
- Auth-account cleanup after a Platform Owner deletes a member profile.
- Firestore indexes for scheduled, retry, and abandoned-processing jobs.
- Client rules that stop users from forging provider IDs or delivery results.

Firebase currently supports Node.js 22 and recommends Secret Manager-backed
parameters; this code uses `defineSecret` and does not use the deprecated
`functions.config()`. See [manage function runtimes](https://firebase.google.com/docs/functions/manage-functions)
and [environment configuration](https://firebase.google.com/docs/functions/config-env).

## 1. Create the MSG91 account and key

1. Sign up at [MSG91](https://control.msg91.com/signin/) using the company
   account that will own production messaging.
2. Complete business/KYC information and add wallet credit if a paid channel
   needs it.
3. In MSG91, open **Settings → Authkey** (the wording can vary), create a
   restricted production auth key, and copy it once.
4. Do not paste the key into `.env`, Flutter, Firestore, screenshots, or this
   repository.

Add it directly to Google Secret Manager from the repository root:

```powershell
firebase functions:secrets:set MSG91_AUTH_KEY --project clinical-solution-5dc1d
```

The CLI securely prompts for the value. Create a separate random webhook secret
and store that the same way:

```powershell
firebase functions:secrets:set NOTIFICATION_WEBHOOK_SECRET --project clinical-solution-5dc1d
```

Use at least 32 random characters. A password manager can generate it.

## 2. Configure India SMS

Commercial/transactional SMS sent to Indian numbers must follow TRAI DLT rules.
Register the business as a Principal Entity on a DLT operator portal, then
register a sender/header and the exact consented appointment reminder template.
Allow time for operator approval.

In MSG91:

1. Open **SMS → Templates/Flows → Add Template**.
2. Enter the approved DLT template ID and sender ID.
3. Make the MSG91 Flow variables match these case-sensitive API names:
   `patient_name`, `clinic_name`, and `message`.
4. Copy the generated MSG91 Flow/template ID.

The current endpoint is MSG91's `POST /api/v5/flow`; see the
[official Send SMS API](https://docs.msg91.com/sms/send-sms) and
[Add Template API](https://docs.msg91.com/sms/add-flow).

## 3. Configure email

1. Open **Email → Domains** in MSG91 and add a dedicated sending subdomain such
   as `notify.exampleclinic.com`.
2. Add every DNS record shown by MSG91. This normally includes SPF and DKIM;
   publish DMARC as well. Wait until MSG91 reports the domain verified.
3. Create an email template with variables `patient_name`, `clinic_name`, and
   `message`. Copy its template ID.
4. Use a sender on the verified domain, for example
   `reminders@notify.exampleclinic.com`. Do not use a personal Gmail address.

The backend follows the current [MSG91 Send Email API](https://docs.msg91.com/email/send-email).

## 4. Configure WhatsApp

1. In **MSG91 → WhatsApp**, connect the clinic's Meta Business account and
   verify the WhatsApp Business number.
2. Create a Utility template such as `appointment_reminder` with exactly three
   body placeholders in this order: patient name, clinic name, reminder text.
3. Submit it for Meta approval. Business-initiated reminders must use an
   approved template; do not use a free-form session endpoint for scheduled
   messages.
4. Copy the approved template name, language, namespace, and integrated number
   including country code.
5. Record patient opt-in outside the message itself and provide an opt-out
   process. The app will send only reminders whose `consent` is `true`.

See the current [MSG91 WhatsApp API overview](https://docs.msg91.com/whatsapp)
and [template creation API](https://docs.msg91.com/whatsapp/create-whatsapp-template).

## 5. Put non-secret identifiers in the correct file

Copy `functions/.env.example` to
`functions/.env.clinical-solution-5dc1d` and fill in the IDs:

```dotenv
MSG91_DEFAULT_COUNTRY_CODE=91
MSG91_SMS_TEMPLATE_ID=your_msg91_flow_id
MSG91_WHATSAPP_TEMPLATE_NAME=appointment_reminder
MSG91_WHATSAPP_NAMESPACE=your_namespace
MSG91_WHATSAPP_INTEGRATED_NUMBER=9198XXXXXXXX
MSG91_EMAIL_TEMPLATE_ID=your_email_template_id
MSG91_EMAIL_DOMAIN=notify.exampleclinic.com
MSG91_EMAIL_FROM=reminders@notify.exampleclinic.com
MSG91_EMAIL_FROM_NAME=Example Clinic
```

The real environment file is git-ignored. Only `.env.example` is committed.
These are provider identifiers, not authentication secrets, but keeping the
environment-specific values out of source control avoids accidental production
configuration changes.

For local emulation only, Firebase supports `functions/.secret.local`. It is
also git-ignored:

```dotenv
MSG91_AUTH_KEY=local-or-test-key
NOTIFICATION_WEBHOOK_SECRET=local-random-secret
```

Never use the production auth key when running local tests.

## 6. Install, verify, and deploy

Use Firebase CLI 15 or newer and a Blaze Firebase project because scheduled
functions require billing. From the repository root:

```powershell
cd functions
npm ci
npm test
cd ..
firebase deploy --only functions,firestore:rules,firestore:indexes --project clinical-solution-5dc1d
```

The first deploy creates one Cloud Scheduler job. Firebase documents that each
job costs US$0.10/month, with three jobs per Google account included at no
charge: [scheduled functions](https://firebase.google.com/docs/functions/schedule-functions).

After deployment, confirm these functions exist in `asia-south1`:

- `dispatchDueReminders`
- `msg91DeliveryWebhook`
- `sendTestNotification`
- `deleteAuthUserAfterProfileDeletion`

## 7. Configure delivery callbacks

The deployed webhook URL is printed by Firebase. In MSG91's delivery/report
webhook settings, set the callback to:

```text
https://asia-south1-clinical-solution-5dc1d.cloudfunctions.net/msg91DeliveryWebhook?secret=YOUR_WEBHOOK_SECRET
```

Prefer an `x-webhook-secret` header if the MSG91 screen supports custom headers;
otherwise use the query parameter. Use the same value stored in
`NOTIFICATION_WEBHOOK_SECRET`. The function accepts POST only and updates a
reminder only when its MSG91 message ID matches.

## 8. Send and verify a reminder

In the app, open **Reminders → Schedule**, choose `sms`, `whatsapp`, or `email`,
enter the recipient, and select a future time. Phone numbers should include the
country code (for example `919876543210`); ten-digit Indian mobile numbers are
automatically prefixed with `91`.

The document moves through:

```text
scheduled → processing → sent → delivered/read
                         ↘ retry → failed
```

Check the reminder in Firestore and the corresponding MSG91 channel logs. A
failure stores a safe `failure_reason`; credentials and full provider responses
are never written to Firestore or logs.

## Production recommendations

- Use separate MSG91 accounts/keys or subaccounts for development and
  production, and rotate keys at least annually or after staff changes.
- Keep reminder text minimal. Avoid diagnoses, test results, prescriptions, or
  other sensitive clinical data in SMS/email/WhatsApp.
- Obtain explicit channel consent and retain when/how it was collected.
- Set MSG91 wallet/spending alerts and Firebase budget alerts; pricing is an
  operational setting, not a code constant.
- Use one general appointment template first. Add vaccination, payment, and
  follow-up templates only after message wording and consent are approved.
- Periodically review Firebase runtime support and run `npm outdated` before a
  planned upgrade. Do not auto-upgrade production dependencies without tests.

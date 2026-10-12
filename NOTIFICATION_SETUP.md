# MSG91 and Twilio notification setup

Last verified: **11 September 2026**

The clinic platform sends scheduled email, SMS, and WhatsApp reminders from
Firebase Functions through MSG91, Twilio, or both. The Product Owner selects a
global primary provider and optional fallback; that policy applies to every
clinic. The retired Firebase Trigger Email extension is not used. Provider keys
never enter Flutter, Firestore, source control, or a browser bundle.

For the Product Owner's event-specific SMS/email editor, lifecycle messages,
language overrides and deployment order, see [Notification templates](NOTIFICATION_TEMPLATES.md).

## Recommended provider policy

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

Start with **MSG91 primary and Twilio fallback** for an India-first deployment.
This uses MSG91's lower domestic SMS price in normal operation while retaining
Twilio as an operational fallback. You can reverse or disable this routing from
**Clinic setup → Global notifications** without redeploying functions.

Provider adapters are isolated in `functions/src/msg91.ts` and
`functions/src/twilio.ts`; provider code and credentials never enter Flutter.

## What is already implemented

- Firebase Functions Gen 2 on the supported Node.js 22 runtime.
- A scheduler that runs every minute in `asia-south1` / `Asia/Kolkata`.
- Atomic claiming, a five-minute lease, a maximum of three attempts, and
  exponential retry for timeouts, HTTP 429, and server errors.
- MSG91 Flow SMS, template email, and approved-template WhatsApp calls.
- Twilio Messages API for SMS/WhatsApp and Twilio SendGrid v3 for email.
- Global primary/fallback routing managed only by Product Owner/Super Admin.
- Protected MSG91 and cryptographically validated Twilio delivery webhooks.
- An authenticated admin-only test function with optional provider override.
- Auth-account cleanup after a Platform Owner deletes a member profile.
- Firestore indexes for scheduled, retry, and abandoned-processing jobs.
- Client rules that stop users from forging provider IDs or delivery results.

Firebase currently supports Node.js 22 and recommends Secret Manager-backed
parameters; this code uses `defineSecret` and does not use the deprecated
`functions.config()`. See [manage function runtimes](https://firebase.google.com/docs/functions/manage-functions)
and [environment configuration](https://firebase.google.com/docs/functions/config-env).

## 1. Create the provider accounts and secrets

### MSG91

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

### Twilio and SendGrid

1. Create a [Twilio account](https://console.twilio.com/) and complete business
   verification and the relevant India regulatory registration.
2. Copy the Account SID and Auth Token from the Twilio Console.
3. Enable Twilio SendGrid, authenticate a sending domain, create a restricted
   Mail Send API key, and keep that key separate from the Twilio Auth Token.
4. Add all three values to Firebase Secret Manager:

```powershell
firebase functions:secrets:set TWILIO_ACCOUNT_SID --project clinical-solution-5dc1d
firebase functions:secrets:set TWILIO_AUTH_TOKEN --project clinical-solution-5dc1d
firebase functions:secrets:set SENDGRID_API_KEY --project clinical-solution-5dc1d
```

The implementation uses Twilio's current
[Messages resource](https://www.twilio.com/docs/messaging/api/message-resource),
[Content Template Builder](https://www.twilio.com/docs/content/create-templates-with-the-content-template-builder),
and [SendGrid v3 Mail Send API](https://www.twilio.com/docs/sendgrid/api-reference/mail-send/mail-send).

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

## 5. Configure Twilio channels

### SMS

Create a Messaging Service and attach an approved sender. For India, complete
Twilio's current regulatory/DLT onboarding and make the outbound content match
the approved template. Copy the Messaging Service SID (`MG...`). A direct
`From` sender is supported when a Messaging Service is not used, but the
Messaging Service is recommended. Optionally use an approved Content SID
(`HX...`) whose variables are `{{1}}` patient name, `{{2}}` clinic name, and
`{{3}}` reminder message.

Use Twilio's current [India SMS guidelines](https://www.twilio.com/en-us/guidelines/in/sms)
and [DLT registration instructions](https://help.twilio.com/articles/21162166457755-Documents-Required-and-Instructions-to-Register-Your-Alphanumeric-Sender-ID-in-India)
when preparing production traffic.

### WhatsApp

Connect a WhatsApp Business sender in Twilio, then create and submit a Utility
Content Template with the same three ordered variables. Copy the approved
Content SID (`HX...`) and WhatsApp sender number. Scheduled business-initiated
messages must use an approved template and patient opt-in.

### Email through Twilio SendGrid

Authenticate a dedicated sending domain using every DNS record supplied by
SendGrid. Create a Dynamic Template containing `patient_name`, `clinic_name`,
and `message`, then copy its `d-...` template ID and verified sender address.

## 6. Configure the global routing policy

Sign in as Product Owner/Super Admin and open:

```text
Clinic setup → Global notifications → Configure providers
```

Choose the primary provider, enable/disable fallback, select the other provider
as fallback, and enter both providers' sender/template identifiers. Select
**Apply to all clinics**. The values are stored at
`platform_settings/notifications`, readable and writable only by the Platform
Owner role. Clinic admins cannot change the platform-wide routing.

When fallback is enabled, a failed primary API request is attempted once using
the other provider. A scheduled retry occurs only if neither provider accepts
the request.

## 7. Environment defaults for first deployment

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
TWILIO_MESSAGING_SERVICE_SID=MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_SMS_FROM=
TWILIO_SMS_CONTENT_SID=
TWILIO_WHATSAPP_FROM=14155238886
TWILIO_WHATSAPP_CONTENT_SID=HXxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
SENDGRID_FROM_EMAIL=reminders@notify.exampleclinic.com
SENDGRID_FROM_NAME=Example Clinic
SENDGRID_TEMPLATE_ID=d-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_STATUS_CALLBACK_URL=https://asia-south1-clinical-solution-5dc1d.cloudfunctions.net/twilioDeliveryWebhook
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
TWILIO_ACCOUNT_SID=AC-local-test-value
TWILIO_AUTH_TOKEN=local-test-token
SENDGRID_API_KEY=local-test-key
```

Never use the production auth key when running local tests.

## 8. Install, verify, and deploy

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
- `twilioDeliveryWebhook`
- `sendTestNotification`
- `deleteAuthUserAfterProfileDeletion`

## 9. Configure delivery callbacks

### MSG91

The deployed webhook URL is printed by Firebase. In MSG91's delivery/report
webhook settings, set the callback to:

```text
https://asia-south1-clinical-solution-5dc1d.cloudfunctions.net/msg91DeliveryWebhook?secret=YOUR_WEBHOOK_SECRET
```

Prefer an `x-webhook-secret` header if the MSG91 screen supports custom headers;
otherwise use the query parameter. Use the same value stored in
`NOTIFICATION_WEBHOOK_SECRET`. The function accepts POST only and updates a
reminder only when its MSG91 message ID matches.

### Twilio

Set the exact callback URL below in the global owner screen and in the Twilio
Messaging Service status callback configuration:

```text
https://asia-south1-clinical-solution-5dc1d.cloudfunctions.net/twilioDeliveryWebhook
```

Twilio signs callbacks with `X-Twilio-Signature`. The function recomputes and
compares the HMAC signature using `TWILIO_AUTH_TOKEN` before updating a
reminder. The configured URL must match exactly—including scheme, host, path,
and any query string—or validation will fail. See Twilio's
[webhook security documentation](https://www.twilio.com/docs/usage/webhooks/webhooks-security).

SendGrid email is marked accepted from its HTTP 202 response. Add a signed
SendGrid Event Webhook in a later phase if delivered/bounce/open tracking is
required; do not point SendGrid events at the Twilio Messaging callback.

## 10. Send and verify a reminder

In the app, open **Reminders → Schedule**, choose `sms`, `whatsapp`, or `email`,
enter the recipient, and select a future time. Phone numbers should include the
country code (for example `919876543210`); ten-digit Indian mobile numbers are
automatically prefixed with `91`.

The document moves through:

```text
scheduled → processing → sent → delivered/read
                         ↘ retry → failed
```

Check the reminder in Firestore and the corresponding MSG91 or Twilio channel
logs. The `provider` field records which provider accepted the message. A
failure stores a safe `failure_reason`; credentials and full provider responses
are never written to Firestore or logs.

## Production recommendations

### Team invitation email template

Creating a team invitation provisions its Firebase Authentication account and
sends an email through the globally selected provider. The email template must
render the edited `subject` and `message` variables. The invitation editor also
supports `patient_name`, `clinic_name`, `roles`, `action_url`, and `approval_status`.
The email action URL is a Firebase-generated password setup/reset link;
passwords are never included in the message. Optional invitation SMS uses
`CLINIC_APP_URL`, which defaults to `https://clinic.orbyteza.com`.

The invited account remains blocked from clinic data until the Platform Owner
approves it. Members establish their password through the emailed link, then
sign in after approval. Existing accounts keep their password when an invitation
is resent. The existing mandatory-password-change policy remains supported.
Verify provider template mappings before inviting production users.

The **Team & roles → Pending approvals** menu shows the current email state and
provides **Approve member**, **Resend invitation email**, and **Reject &
remove** actions. Resend also processes invitations created before the latest
notification functions were deployed. Both `provisionInvitedMember` and
`resendInvitedMemberEmail` must be deployed for automatic and manual delivery.
Deploy `approveInvitedMember` as well so approval can create the account without
requiring the invited person to register first.

- Use separate MSG91 and Twilio accounts/keys or subaccounts for development and
  production, and rotate keys at least annually or after staff changes.
- Keep reminder text minimal. Avoid diagnoses, test results, prescriptions, or
  other sensitive clinical data in SMS/email/WhatsApp.
- Obtain explicit channel consent and retain when/how it was collected.
- Set provider wallet/spending alerts and Firebase budget alerts; pricing is an
  operational setting, not a code constant.
- Use one general appointment template first. Add vaccination, payment, and
  follow-up templates only after message wording and consent are approved.
- Periodically review Firebase runtime support and run `npm outdated` before a
  planned upgrade. Do not auto-upgrade production dependencies without tests.

# MSG91 integration test readiness

## Status (28 October 2026)

The existing Firebase Functions MSG91 adapter is retained. Its response handling now recognizes SMS receipts in `message` and email receipts in `data.unique_id`, rejects HTTP-200 application errors, and treats a response without a receipt as unknown rather than automatically retrying it. Event SMS requires its own template; template variables cannot override the recipient. TypeScript compilation and all 32 compiled backend unit tests passed. IP allowlist errors now produce a specific setup diagnostic and are not retried.

The local root `.secret.local` is ignored by Git. It must never be bundled into Flutter assets, committed, or copied into a client configuration. Production Functions still require their existing Secret Manager configuration; a local key does not configure deployed functions.

MSG91 MCP was reachable but exposed documentation tools only. The requested DocStar CLI modules were installed. A read-only email-template lookup using the supplied key still returned HTTP 401 with `apiError: 418` on 28 October. MSG91 documents 418 as **IP not whitelisted**, so this does not establish that the key itself is invalid.

Email is now active. The browser confirms approved template `clinic_integration_test`, internal template ID `74125`, version `107225` (v1.0). Its editor contains the synthetic body below. An extra v1.1 draft was opened during content verification and has not been submitted or made active.

One email was submitted through the dashboard's **Send Test Email** flow to the explicitly authorized internal account recipient, from `clinictest@rpirf9.mailer91.com`, using the account's provider-supplied dummy domain. MSG91's email log records it at `2026-10-28 06:14:14`, source `API`, status **Delivered — OK**, updated at `2026-10-28 06:14:31` after initially being queued. Request receipt: `0cb98557088009a01526f67a678a65505ec38618`. Screenshot evidence is in the ignored local file `build/msg91-email-test-delivered.png`. This confirms provider-reported delivery. Startup benefits activation still requires MSG91 confirmation. No SMS has been sent. The SMS Sender ID and Templates lists were empty, and the user confirmed that DLT approval is unavailable.

## Account prerequisites

1. Open SMS → Failed Logs and locate the rejected request's source IP. Under Authkey → that key → Whitelisted IPs, authorize the intended test host's specific IP while retaining API security. Production Firebase egress must be planned separately; a workstation allowlist does not authorize deployed functions.
2. For India SMS, use the actual approved sender/header and DLT template ID, with exact matching approved content. Do not invent IDs or substitute an unrelated approved template.
3. Activate the Email service after reviewing any plan or subscription terms. Then verify an owned sending domain through MSG91's DNS verification flow and select an authorized From address. The test recipient is not automatically a verified sender.

## Prepared synthetic templates

Approved email template name: `Clinic_integration_test`; actual template slug: `clinic_integration_test`.

Subject: `Clinic notification integration test`

Body:

```html
<!doctype html>
<html lang="en"><body>
  <h1>Clinic notification integration test</h1>
  <p>This is a synthetic test of the clinic application's email integration.</p>
  <p>No appointment has been booked or changed. No payment is due.</p>
  <p>No patient information is included. No action is required.</p>
</body></html>
```

Proposed SMS content, subject to the actual DLT approval:

```text
Orbyteza clinic notification integration test. No appointment or payment was created. No action is required.
```

Keep these test templates separate from event-specific production templates. The existing event catalog and localized notification workflows must retain their own approved mappings.

## Controlled live test

After account prerequisites pass, list templates before creating one to avoid duplicates. Create the email HTML template through `email create-new-template`; inspect its approval/active state. Create the SMS template through `sms add-flow` only with the real sender and DLT identifiers. Send one synthetic SMS and one synthetic email to the recipients explicitly authorized in this task. Record the response receipt and inspect provider delivery logs. Provider acceptance does not prove delivery or activation of Startup benefits. On an ambiguous timeout, inspect logs before any resend. Do not enable global production delivery merely to run this test.

## Official references

- [API index](https://docs.msg91.com/llms.txt)
- [API security and error 418](https://msg91.com/help/api/what-do-you-mean-by-api-security)
- [SMS template setup](https://msg91.com/help/template/how-to-create-flow-id-to-send-sms-via-api)
- [Email domain setup](https://msg91.com/help/email/how-to-set-up-start-using-msg91-email-service)
- [Create email template API](https://docs.msg91.com/email/create-new-template.openapi.yml)
- [Create SMS template API](https://docs.msg91.com/sms/add-flow.openapi.yml)

# Current messaging configuration

Authentication uses Firebase Authentication directly: login, password reset, and
registration email verification. Configure authentication email templates in the
Firebase console. The Product Owner editor applies to clinic notifications only.
The legacy password_reset catalog entry is retained for compatibility but hidden
from the editor and its old callable endpoint is no longer exported.

Clinic notifications use MSG91 only, with automatic paid-provider fallback off.
They are disabled by default. Attempts report a configuration failure instead of
claiming successful delivery. No Twilio or SendGrid secrets are required.

To activate:
1. Verify the email sender/domain in MSG91 and configure email templates.
2. Configure the approved India SMS sender and template IDs in MSG91.
3. Set MSG91_AUTH_KEY and NOTIFICATION_WEBHOOK_SECRET in Firebase Secret Manager.
   The webhook secret must be a newly generated random value, also configured
   in the MSG91 delivery callback. Do not put secret values in this repository.
4. Set CLINIC_NOTIFICATIONS_ENABLED=true in functions/.env.clinical-solution-5dc1d
   and configure the non-secret sender/template settings shown in .env.example
   or the Product Owner notification settings. Deploy functions again.
5. Send an explicit test to a designated recipient before enabling clinic sends.
   Notifications that failed before setup must be explicitly retried; they are
   not automatically replayed when messaging is activated.

Provider selection (India, checked 2026-10-12): MSG91 publishes INR 0.25 per SMS
at 5,000 messages and a free plan including 5,000 emails; larger SMS tiers have
lower rates. Twilio lists USD 0.0832 per outbound India SMS segment. Charges,
taxes, Unicode segmentation, registration costs and actual volume affect totals.
https://msg91.com/in/pricing/sms
https://msg91.com/in/pricing/email
https://www.twilio.com/en-us/sms/pricing/in

This document supersedes older instructions requiring all providers or using
custom provider delivery for password reset.

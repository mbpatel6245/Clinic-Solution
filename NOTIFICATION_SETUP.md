# Email, SMS, and WhatsApp reminder setup

The Flutter application stores consent-aware jobs in:

```text
clinics/{clinicId}/reminders/{reminderId}
```

Provider credentials must never be placed in Flutter source code. A trusted
Firebase Cloud Function should read due reminders, call the provider, and then
write `status`, `provider_message_id`, `sent_at`, and `failure_reason`.

## 1. Email

The simplest Firebase-native option is the official **Trigger Email** extension:

```sh
firebase ext:install firebase/firestore-send-email --project=YOUR_PROJECT_ID
```

During installation, configure an SMTP provider such as SendGrid and use a
server-only `mail` collection. A scheduled Cloud Function should convert due
clinic reminders into extension documents containing `to`, `message.subject`,
and `message.html`.

Official guide:
https://firebase.google.com/docs/extensions/official/firestore-send-email

## 2. SMS

1. Create a Twilio account and obtain an SMS-capable sender or Messaging
   Service.
2. Store the Account SID, API key, API secret, and Messaging Service SID in
   Firebase Secret Manager—not Firestore and not the Flutter application.
3. In a scheduled Cloud Function, send due `channel: sms` reminders through
   Twilio's Messages API.
4. Store the returned message SID and delivery state on the reminder.
5. Configure Twilio status callbacks so delivered/failed results are reflected
   in Firestore.

Official guide:
https://www.twilio.com/docs/messaging/tutorials/how-to-send-sms-messages

## 3. WhatsApp

1. Create/verify a WhatsApp Business Account and register a WhatsApp sender in
   Twilio.
2. Create appointment, follow-up, payment, and vaccination templates in the
   Twilio Content Template Builder and submit them for WhatsApp approval.
3. Save only the approved Content SID in clinic notification settings.
4. Send due `channel: whatsapp` reminders from a Cloud Function using the
   approved sender and template variables.
5. Store patient opt-in evidence. Business-initiated messages outside the
   customer-service window require an approved template.

Official guides:
https://www.twilio.com/docs/whatsapp/api
https://www.twilio.com/docs/whatsapp/tutorial/send-whatsapp-notification-messages-templates

## Recommended backend flow

```text
scheduled function (each minute)
  -> query due, consented, scheduled reminders
  -> atomically claim each reminder
  -> send through email/SMS/WhatsApp provider
  -> save provider id and sent/failed state
  -> provider webhook updates delivered/read/failed state
```

Use idempotency keys based on `clinicId/reminderId`, retry only temporary
failures, rate-limit per clinic, and keep message content free of unnecessary
clinical information. Add a clinic-level sender/template configuration screen
only after the backend secrets and functions are deployed.

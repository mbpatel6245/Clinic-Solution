# Clinic Solution email branding

These templates use the existing company logo hosted at https://orbyteza.com/assets/logo-dark.png, ORBYTEZA TECH LLP, and inquiry@orbyteza.com.

- `firebase-verification.html`: proposed verification design; preserve `%LINK%` and `%EMAIL%`.
- `firebase-password-reset.html`: proposed reset design; preserve `%LINK%` and `%EMAIL%`.
- `msg91-clinic-notification.html`: provider template with `{{subject}}` and `{{message}}`. Configure variables as escaped text; do not render recipient-controlled HTML. Apply CSS to preserve line breaks if required by the provider editor.

Firebase's API rejected template edits for this project with `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`. The Firebase project display name has been updated to **orByteza Clinic Solution**, which is substituted for `%APP_NAME%` in its built-in emails. The HTML designs are prepared assets, not active Firebase templates. Built-in Firebase verification links and sending configuration were preserved.

To activate branded clinic emails, create MSG91, verify the sending domain, configure the sender name/address, import the notification template and copy its template ID into Product Owner notification settings. Set the auth key through Firebase Secret Manager. Configure approved SMS/DLT templates separately, then explicitly enable clinic notifications and send controlled test messages. Firebase Authentication emails and MSG91 clinic notifications are separate systems.

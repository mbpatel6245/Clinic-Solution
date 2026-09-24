# clinic_solution

Flutter Clinic Solution for Android, iOS, Linux, MacOS, Web and Windows platform complete solutions

Production web deployments are automated through GitHub Actions. See
[DEPLOYMENT.md](DEPLOYMENT.md) for the one-time SSH-key setup and deployment
details.

## Clinic workflows

- **Enterprise clinic tenancy:** operational data is isolated below each clinic,
  users can hold clinic-specific roles, and multi-clinic accounts can switch
  their active clinic.
- **Configurable modules:** Platform Owners activate purchased Reception,
  Pharmacy, Vaccination, Reminders, Billing, Expenses, Reports, Data Exchange,
  and Laboratory modules independently for each clinic. Clinic Admins manage
  only their clinic's activated workflows.
- **Platform administration:** searchable clinic directory, all-clinic member
  visibility, clinic-role allocation, invitation approval, member editing, and
  access removal. Switching into a clinic never reduces Platform Owner access.
- **Extended roles:** Platform Owner, Clinic Admin, Branch Manager, Doctor,
  Receptionist, Pharmacy Operator, Nurse/Vaccinator, Accountant, and Patient.
- **Billing:** split doctor, clinic/case, and pharmacy line items with paid,
  partial, outstanding, waived, refunded, and cancelled states.
- **Vaccination and reminders:** dose/batch tracking plus consent-aware reminder
  scheduling.
- **Reporting and data exchange:** custom date financial KPIs and clinic-scoped
  patient CSV import/export.

- **New prescription:** patient demographics, diagnoses, complaints, vitals,
  investigations, advice, follow-up date, and structured medicine lines.
- **Prescription list:** live patient search, status filtering, clinical-detail
  view, repeat visits, completion tracking, and record removal.
- **Appointments:** public patient booking at `/appointment`, clinic scheduling,
  date filters, editing, confirmation, completion, and cancellation.
- **Stock inward:** invoice and batch tracking, supplier and expiry details,
  remaining-stock adjustments, and low/out-of-stock/expiry alerts.
- **Clinic overview:** appointment, visit, patient, low-stock, income, expense,
  and net-balance indicators with a compact performance visualization.
- **Finance ledger:** income and expense entry, categorization, history, and
  monthly totals for clinic administrators.
- **Role workspaces:** Admin, Doctor, Patient, and Pharmacy Operator receive
  only the navigation and workflows required for their work. Admins can assign
  roles from the Team screen; public registration creates Patient accounts.
- **Offline-aware operation:** cached records remain available and supported
  Firestore writes queue locally, show connection state, and synchronize when
  the connection returns.
- **Localization:** English, Hindi, and Gujarati across the clinic workflows.

The workflows use the Firestore collections `patients`, `prescriptions`,
`appointments`, and `stocks` below `clinics/{clinicId}`. Existing legacy stock
documents are read through a compatibility mapper. Follow
[ENTERPRISE_MIGRATION.md](ENTERPRISE_MIGRATION.md) before deploying the included
role-based rules:

```sh
firebase deploy --only firestore:rules
```

Notification providers are configured globally by the Platform Owner, with
MSG91/Twilio primary and optional fallback routing. Credentials remain
server-side. See [NOTIFICATION_SETUP.md](NOTIFICATION_SETUP.md) for email, SMS,
WhatsApp, templates, callbacks, and Secret Manager setup.
The Platform Owner can edit event-specific SMS and email messages under
**Clinic setup → SMS & email templates**. See
[NOTIFICATION_TEMPLATES.md](NOTIFICATION_TEMPLATES.md) for supported events,
language overrides, delivery behavior and backend rollout steps.

Persistent offline caching is enabled on Web, Android, iOS, and macOS. Windows
uses the connected Firestore client without persistent cache. The official
FlutterFire plugins used by this project do not currently provide a Linux
desktop implementation, so Linux displays a supported-platform notice and the
web build should be used there for the complete connected/offline experience.

## Getting Started

Use Flutter `3.47.0` (the version configured in GitHub Actions), then run:

```sh
flutter pub get
flutter gen-l10n
flutter run
```

Firebase must be configured for the target platform. Public appointment creates
also require Firestore rules that allow validated appointment creation while
keeping appointment reads and updates restricted to authenticated clinic staff.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# clinic_solution

Flutter Clinic Solution for Android, iOS, Linux, MacOS, Web and Windows platform complete solutions

Production web deployments are automated through GitHub Actions. See
[DEPLOYMENT.md](DEPLOYMENT.md) for the one-time SSH-key setup and deployment
details.

## Clinic workflows

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
`appointments`, and the existing `stocks` collection. Existing legacy stock
documents are read through a compatibility mapper. Deploy the included
role-based rules before enabling the role workspaces in production:

```sh
firebase deploy --only firestore:rules
```

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

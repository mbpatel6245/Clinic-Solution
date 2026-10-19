# Clinic revamp: reviewed workflows and delivery status

Branch: `clinic-revamp`. Review date: 19 October 2026. This is a feature inventory and branch status, not a claim of complete parity or production deployment.

## Authenticated review

Reviewed [myDoc.fit](https://mydoc.fit/dashboard) in the user's authenticated browser: dashboard/full analytics, queue, patient registration, consultation, Rx preview, patient analytics/timeline, treatment planning, vaccinations, profile/location settings, prescription designer, templates, staff permissions and account/usage. Browser capture now works; the earlier limitation is resolved.

The user authorized dummy records and enabling the Treatment Plan Tab. Created one clearly labelled demo clinic, a synthetic patient without contact details or identifiers, one synthetic consultation using a fake non-medicine entry, and a zero-price treatment plan. Verified consultation completion removed the patient from Live and added them to Completed. No treatment sitting, real medication, payment, external message, subscription purchase or account deletion was performed. Dummy records remain. Screenshot proof is in ignored `build/revamp-review/demo-treatment.jpg`; source control excludes account identifiers and proprietary assets.

## Feature coverage

“Implemented” means branch code, not deployed production functionality. “Existing” means retained earlier functionality.

| Workflow | Reviewed reference behavior | Our implementation / remaining work |
| --- | --- | --- |
| Overview | Metrics, privacy, chart, diagnoses, actions | Implemented responsive Flutter dashboard with granted-feature subscriptions, loading/errors and privacy toggle |
| Analytics | Period/custom dates, demographics, diagnoses, medications, no-shows | Implemented calendar filters, age/gender, medication counts and explicit-outcome no-show rate; peak hours, wait-time trends and comparisons remain |
| Payments | Collected/latest/all payments | Existing invoice/partial payments plus invoice-period summary; payment-event ledger remains |
| Queue | Scheduled/live/done, walk-ins, vitals, timers, priority order | Implemented search/count tabs, check-in, consultation, complete/cancel/no-show and atomic consultation-to-queue completion; structured vitals, timers and reordering remain |
| Registration | Age units/DOB, gender, ABHA, allergies, contact/consent | Implemented registry independent of billing/booking, demographics, allergies and consent; existing walk-ins retained |
| Patient record | Timeline, analytics, repeat visit, documents, risk markers | Clinician-only history and new consultation implemented; rich timeline, existing-profile editing, documents and risk markers remain |
| Consultation | Symptoms/durations, ICD/medicine search, tests/advice, follow-up | Existing editor retained and private notes separately protected; licensed catalogs, structured vitals and automatic follow-up remain |
| Templates | Save/use/update Rx, custom symptom/test/advice lists | Implemented identity-free templates and non-destructive apply/update; shared terminology/advice library remains |
| Rx output/design | PDF/print, translation/share, themes/header/signature/QR | Implemented save-and-preview, saved-record preview, native/system print and PDF export, three letterheads, clinician/registration/footer fields, margins/text size and visibility controls; English/Hindi/Gujarati labels with original clinical text. Header/signature uploads, QR and AI translation remain |
| Treatment plans | Procedures/prices, sittings, work/payment log, close/cancel | Typed plans, transaction-based sitting work/private-note logs, progress, completed/cancelled/reopen lifecycle and immutable history implemented; procedure prices and package billing remain |
| Quick procedures | Procedure name, optional cost/notes, optional Cash/UPI/Card/Other collection; inspected without saving | Implementation remains |
| Lab | Manual values/ranges/trends and PDF/image scan | Numeric observations, reported ranges and same-patient/analyte/unit chart implemented; file ingestion and reviewed AI extraction remain |
| AI | Paid scan, translation, consultation-assistance controls | Disabled Google Vertex backend and authenticated Flutter adapter prepared; review UI, uploads and production configuration remain |
| Certificates | Medical/fitness/referral/letter, editable preview, PDF/share | Dialog inspected without issuing; implementation remains |
| Old records | Import/history entry | Existing data exchange retained; patient document ingestion and chronological import remain |
| Vaccination | DOB-aware/custom schedule, given/pending, print | Existing records/reminders/due list retained; configurable schedule engine and print schedule remain |
| Staff entry | Separate route, doctor-created username/password | Separate email/password route and clinic role checks implemented; username mapping remains |
| Doctor entry | Google sign-in and phone linking | Existing Firebase email/password/recovery retained; Google/phone flows and native OAuth setup remain |
| Staff access | Operational queue/patients/vitals/today billing; no clinical editor/settings | Reception workspace and protected clinical collections implemented. Today-only billing is UI filtering, not a backend query restriction |
| Staff messages | Presets, text, replies | Immutable clinic messages and last-50 display implemented; presets, replies, unread alerts remain |
| Booking | Daily appointments, online requests accept/decline | Existing booking retained; request workflow, exceptions and conflict-safe slots remain |
| Locations | Fees, multiple sessions, slots, holiday overrides | Existing clinic hours/days/timezone/modules retained; multi-location sessions/overrides remain |
| Public presence | Bio/services/links/slug/QR/video | Existing marketing/booking retained; clinician microsite, QR and video remain |
| Communications | Consent-gated WhatsApp | Existing owner-editable SMS/email templates/outbox retained; provider setup still required; no messages sent during review |
| Plans/billing | Free allowance, subscriptions, credits, GST invoices | Inspected without checkout; subscription enforcement, credit ledger and tax invoices remain |

## Data, design and localization

Original orByteza identity, grouped searchable desktop sidebar, tablet/mobile drawer and bottom navigation. Pages build on first visit and preserve form state; clinic/module changes reset the workspace. Failed metrics display unavailable values rather than zero. Queue outcomes are persisted; wait-time metrics are not invented.

New workspace copy supports English/Hindi/Gujarati with locale fonts and large-text spacing. Older dialogs still have English strings. The pre-existing public homepage remains HTML; new application work is Flutter. Porting the homepage remains part of the all-Flutter objective.

Financial values sum cumulative payments against invoices **issued in the selected period**, not cash received during that period. Outstanding balances cover all loaded invoices. Full-history listeners still need paging, bounded queries and aggregates for large-scale costs.

New rules protect private notes separately from shared prescriptions, forbid identity fields in templates, restrict plans to clinicians/admins and enforce clinic/sender identity for immutable team messages. AI usage is server-only. Rules are not deployed by this branch; new collections require a coordinated rules release.

Prescription printing uses an explicit patient-facing field whitelist; private visit notes, ABHA, account identifiers and email are excluded. Each page repeats clinic letterhead, patient name/date and page count. Clinical text is shaped by Flutter into high-resolution images to preserve Indic typography. The resulting clinical text is not searchable/copyable yet. Language selection changes document labels/dates only; it never silently translates medicines or instructions. Oversized documents fail instead of truncating clinical content. Saved letterheads are clinic-scoped and writable only by administrators; viewing a preview does not send a message. Printing/share actions require the application user's explicit action.

Sitting logs save progress and history atomically after re-reading the plan, using one log ID per sitting to prevent duplicate completion. Work/date/private notes are retained on save failure. Logs cannot be rewritten by clients, and front desk/patient/other-clinic access is denied. Closed/cancelled plans can be reopened without erasing previous work. This does not yet implement payments or an amendment workflow for signed-off notes.

## Google AI decision

The owner selected the existing Firebase project. Server identity calls Vertex AI without a client API key or new AI provider. Usage stays disabled. Prepared tasks are report **text** extraction, English/Hindi/Gujarati translation and consultation-note organization. Image/PDF scanning, diagnostic decisions and automatic chart writes are not implemented. See [setup and release gates](google-ai-setup.md).

## Platforms and pricing

Flutter shares UI/Dart across web/mobile/desktop, but backend support differs. See [Flutter platforms](https://docs.flutter.dev/reference/supported-platforms) and [Firebase plugins](https://firebase.google.com/docs/flutter/setup#available-plugins). Windows Firebase is documented for local development; native Linux requires a maintained backend adapter. Browser delivery remains available. All seven CI jobs for foundation commit `a9abc5e` passed: web/tests/access rules, Android, iOS, macOS, Windows and Linux. Later commits are independently checked by the same workflow. macOS print and outbound-network entitlements are configured; iOS already uses frameworks. Signed-device printing, OAuth, plugin support and offline/reconnect remain release validation. Local Windows dependency setup reports missing symlink/Developer Mode support; no system security settings were changed.

The [official competitor page](https://mydoc.fit/for-doctors) listed ₹999/month or ₹9,999/year before GST when reviewed. Proposed ₹499/month or ₹4,999/year before tax are planning figures, not active prices or confirmed profitable terms. At ₹499 net monthly revenue, a 70% margin target allows about ₹150 variable costs. Measure infrastructure, delivery and support before setting allowances. Meter SMS/email and AI separately; do not promise unlimited usage.

## Checks and acceptance

Tests exercise responsive English/Hindi/Gujarati dashboards at 320/768/1440 widths with large text, editor persistence, private-note separation, queue completion, templates, demographic metrics and role gates. Real Firestore emulator tests cover cross-clinic access, patient/staff denial, identity rejection and message spoofing. AI tests use synthetic data and mocked providers. Final counts/build results belong in the delivery report after the last run.

Complete the remaining rows before claiming every reference feature. No main deployment is part of this branch work.

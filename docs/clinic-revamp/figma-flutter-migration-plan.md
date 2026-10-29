# Figma-led Flutter revamp: assessment and proposed migration

Date: 26 October 2026. Repository baseline: `clinic-revamp`, commit `6969e86`.
Status: original analysis and proposal, followed by the authorized [Phase 1 foundation implementation](phase-1-foundation.md). The assessment itself preceded application changes; the linked implementation report records subsequent work and validation.

## Recommendation

Evolve this application in place. Keep Flutter, Provider/ChangeNotifier, GoRouter, the existing Firebase project, clinic-scoped document paths, model compatibility and working workflows. Introduce feature-level repository interfaces and a transactional local database incrementally. Add a shared synchronization engine with an explicit durable outbox instead of treating a timed-out Firestore call as a confirmed save.

Use the supplied Uvilo Figma design for visual direction. Preserve operational features absent from those frames, including pharmacy, inventory, expenses, data exchange, notification administration and Platform Owner tools. Separate the visual migration from additions such as phone authentication, immutable clinical releases, patient messaging and payment processing.

First implementation milestone: a responsive Staff patient-directory/registration slice, backed by the existing remote contracts and the proposed local store, that survives an offline save, process restart and reconnect without duplication or cross-clinic leakage. Prove Windows and Linux connectivity during that foundation milestone rather than leaving desktop feasibility to the end.

## Evidence and limits of this review

- Read the attachment and matched all **59 unique node IDs** against the Figma file: **57 numbered screens, Doctor Patient overview, and the primary logo**. Retrieved full design context and screenshots for all 59; inspected the hierarchy/content across the set and visually inspected representative access, staff, doctor, patient, admin and public screens. No returned context was marked sparse. This is a design/interaction inventory, not a rendered Flutter fidelity certification or a click-tested Figma prototype.
- The detailed [59-node implementation matrix](figma-screen-matrix.md) records the intended flows, existing code to reuse, gaps and delivery phase. Existing workflows were reviewed in source, not against live patient data.
- Inspected bootstrap, navigation, design tokens, role/session handling, domain-like models, Firestore service methods, Firebase configuration/rules/indexes, notification and AI functions, representative workflows, tests and CI. The prior [review and scope report](review-and-scope.md) is useful historical context, but describes an earlier reference and is not evidence that this Figma design is already implemented.
- Working tree was clean at the start. No applicable `AGENTS.md` was found in the project or its parent directories.
- The initial test attempt hit an SDK-cache permission restriction. A subsequent approved invocation of the cached Flutter tool completed the baseline: **122 tests passed**. See the Phase 1 implementation report for later regression, storage, browser and platform checks. Remote CI success has not been independently revalidated.
- Repository configuration identifies Firebase project `clinical-solution-5dc1d`. Deployed rules, enabled authentication providers, actual Storage usage, production indexes and service configuration require environment verification before implementation rollout. No production connection or deployment was performed.

## Current application: what to preserve and change

Paths below are relative to the repository root.

| Area | Verified implementation | Recommended treatment |
| --- | --- | --- |
| Stack | Flutter; Dart SDK constraint `>=3.10.0 <4.0.0`; CI pins Flutter 3.47.0; Provider, GoRouter, Firebase Auth/Core/Firestore, HTTP, PDF/printing, timezone, shared_preferences | Keep the established stack; avoid a simultaneous state-management rewrite or blanket dependency upgrade |
| UI foundation | `lib/core/design/app_theme.dart`, locale typography, `lib/ui/widgets/app_design.dart`, common controls, responsive workspace navigation and preserved tab state | Extend these foundations with Figma tokens and adaptive layouts; migrate widgets as their feature changes |
| Workflows | Registry, patient intake, appointment scheduling, queue, consultation, prescription/PDF, lab observations, treatment sittings, vaccination, billing, finance, inventory, reports, team/admin and data exchange | Preserve behavior through repository adapters and regression tests; Figma is not the complete parity inventory |
| Business/data access | `lib/services/firestore_services.dart` is approximately 1,600 lines and spans many features; views consume its concrete class directly | Split by feature behind interfaces, starting with patients and appointments; retain the old facade for unmigrated screens |
| Models | `clinical_models.dart`, `enterprise_models.dart`, `workflow_models.dart` contain useful typed fields and compatibility logic but import Firestore types | Preserve serializers as data DTOs; extract pure Dart entities/value objects only as each feature migrates |
| Identity/tenancy | `SessionController`, `AppRole`, clinic memberships, purchased modules and clinic-specific role lists | Reuse memberships and IDs; add an explicit capability resolver and account/clinic-scoped session lifecycle |
| Routes | Six top-level GoRouter routes; much workspace navigation lives in selected indices/state in `HomeScreen` | Add named nested feature routes, deep links and guards while keeping existing links working |
| Firebase functions | Server notification outbox, scheduled reminders, MSG91/Twilio delivery callbacks, invitation provisioning/approval, cleanup, prepared clinical AI callable | Keep contracts and secrets server-side; add sync/transaction endpoints only where necessary |
| Storage | Bucket configuration exists; no `firebase_storage` client dependency, upload implementation or Storage rules configuration found in the reviewed source | Preserve bucket/configuration; audit deployed use before adding document upload/download and rules. Do not describe uploads as already functional |
| AI | Disabled HTTP adapter and App Check-enforced callable exist; text tasks are prepared | Keep disabled until authorized upload, source review, access controls, metering and desktop App Check strategy are validated |
| Localization | English, Hindi, Gujarati and bundled Noto fonts; some older screens use literal English | Retain all three languages and Indic print behavior; move new strings into ARB resources |
| Deployment | Web marketing HTML/JS bootstraps Flutter for application routes; CI includes six platform builds | Migrate the public experience into Flutter to meet the shared-codebase objective; retain minimal web host/bootstrap and deliberate URL handling |

### Concrete gaps that affect the migration

1. **Platform support:** `lib/core/platform/firebase_runtime.dart` rejects native Linux and disables persistent Firestore caching on Windows. A successful Linux build currently does not mean a working connected clinic application.
2. **Uncertain save outcome:** `FirebaseFireStore._queueWrite` at line 76 returns after a three-second timeout and logs eventual errors. This cannot provide a durable, inspectable acknowledgement contract across all targets.
3. **Incomplete sync indicator:** `SyncStatusService` reads pending-write metadata from `users/{uid}`. A clean profile snapshot does not establish that all clinic records are synchronized.
4. **Online transactions:** `submitPatientEntry`, stock sales and sitting completion use server transactions. Offline registration/booking cannot simply call these methods and report success. Preserve the transaction invariants when introducing local drafts.
5. **Concurrent booking:** intake checks for occupied slots before its transaction. The current model lacks practitioner identity and explicit duration/end time; it cannot enforce the Figma design's practitioner-specific, variable-duration, non-overlapping schedule.
6. **Access differences:** existing clinic-admin/reception/clinical roles are broader than the Figma capability model. Rules allow clinical access by clinic role rather than individual care assignment. Patient documents mix administrative details with health fields such as allergies; hiding fields in the Staff UI does not prevent a permitted Firestore document read.
7. **Session isolation:** role/name/clinic preferences are stored under global keys, not keyed by UID. `SecureDataViewModel` writes profile strings to shared_preferences; its encryption comments do not implement encryption. Do not use either mechanism as the clinical cache or credential vault.
8. **Scale:** several listeners load complete clinic collections and sort/filter in Dart. Introduce bounded queries, pagination, local indexes and appropriately scoped reporting aggregates.
9. **Clinical lifecycle:** current editable prescriptions, sharing flags and separate private notes are a useful base, but not immutable signed versions with independent release and amendment history.
10. **Payments:** invoices store a cumulative amount paid and payment method. There is no verified payment-attempt ledger or patient payment gateway in the reviewed source. Subscription billing is a separate new domain.

## Figma interpretation and responsive strategy

The numbered frames are 1512 logical units wide. The common app shell has a 216-wide sidebar, toolbar, bordered white panels, pale teal canvas and contextual side panels. The logo frame is 282 by 96. Reviewed typography is Inter; the current application uses Noto Sans. Reviewed base colors include primary `#007C83`, ink `#1F3A3D`, secondary text `#536D72`, canvas `#F4FBFB`, border `#B9DDE0` and soft fill `#E5F3F4`. Cards are commonly 12-radius and controls 8-radius; these should become semantic tokens rather than repeated literals.

Adopt Uvilo visual identity and its supplied logo for the proposed UI; keep existing Firebase IDs and deployment addresses. Do not automatically rename legal entities, bundle identifiers or production domains. Download the exact supplied artwork into versioned local assets during implementation. Use Inter for the Latin design with retained Noto Devanagari/Gujarati fallbacks; validate line height and wrapping in all supported locales.

The long Figma frames often include a main state, a confirmation dialog, subsequent success, and alternative failure states together. These must become separate states/screens, never a single live form displaying contradictory outcomes. Sample patients, IDs, prices, chart values, QR codes and clinical text are design examples, not seed data or default medical instructions.

Retain the existing 600/960/1200 breakpoints as starting points and use `LayoutBuilder` constraints to adapt each region. Layout changes respond to available width, text size and input method, not operating-system names.

| Available width | Navigation | Content and interactions |
| --- | --- | --- |
| Under 600 | Up to four primary role destinations plus More/drawer | One column; directory rows/cards; day agenda instead of week grid; full-screen forms and review steps; primary action reachable above the keyboard |
| 600–959 | Compact navigation rail, drawer for extended destinations | Two-column forms only where labels/values fit; agenda/day schedule; detail page or sheet; no forced dense desktop table |
| 960–1199 | Rail or expanded sidebar when content permits | Main content plus optional details panel; priority table columns; side panels collapse into sections before overflow |
| 1200 and above | Figma-style 216-wide sidebar and toolbar | Main/detail composition, week calendar, paginated tables; constrain reading width on ultrawide displays rather than stretching forms indefinitely |

Use 16/24/32 spacing for adaptive page gutters; preserve the Figma composition at 1512 while keeping narrow-screen body copy readable. Do not shrink 10–13px desktop labels proportionally onto phones. Use at least 48 logical-pixel touch targets for actionable touch surfaces, keyboard focus/shortcuts, semantic labels and status text in addition to color. Keep patient identity and allergy context visible in clinical tasks without crowding small screens. Support landscape, resize, keyboard insets, 200% text scale and screen readers.

Reusable UI set: adaptive shell, clinic switcher, capability-aware destination model, page heading/breadcrumb, patient identity strip, clinical alert, metric card, status chip, searchable/paginated directory, agenda/week calendar, section/form field, review dialog, draft footer, document preview, local-save indicator, sync/conflict center, empty/error/loading/retry surfaces.

Forms retain drafts across navigation, resize and recoverable failure. Mobile back and browser back must restore useful context. New routes should include clinic IDs and entity IDs, with server-backed authorization; URL contents never confer access. Avoid global viewport-derived sizing from legacy `size_utils.dart` in new components.

## Target architecture and state management

**Recommendation: keep Provider + ChangeNotifier, used consistently as feature controllers/view models.** The current stack already supports dependency injection and reactive views. Riverpod or BLoC would also be viable, but switching now adds migration work without solving durability, transactions or authorization. Constructor-inject repositories, clocks, ID generators and transports; keep Provider as the composition mechanism instead of adding another service locator.

Presentation reads immutable view-state objects and sends intents to a controller. Controllers call use cases where a workflow spans multiple invariants. Simple reads can call repository interfaces directly. Domain code does not import Flutter, Firebase, HTTP or database packages. DTOs own Firestore `Timestamp`/field-name compatibility. Data repositories combine local records and remote refresh; widgets never choose the remote transport.

```text
lib/
  app/
    bootstrap.dart
    dependency_scope.dart
    router.dart
    session_scope.dart
  core/
    design/                 # evolve existing tokens, typography and themes
    auth/                   # session identity, clinic scope, capability policy
    errors/                 # typed failures and save outcomes
    platform/               # small platform capability/transport adapters
    persistence/            # database, migrations, key storage interfaces
    sync/                   # outbox, worker, retry, conflicts, cursors
  shared/
    presentation/           # reusable adaptive widgets and states
    documents/              # prescription rendering / PDF / print adapters
  features/
    patients/
      domain/               # entities, repository contracts, use cases
      data/                 # DTOs, local/remote sources, repository implementation
      presentation/         # controller, state, screens, feature widgets
    appointments/           # includes availability and queue
    clinical/               # consultations, Rx, labs, plans, vaccinations
    billing/                # encounter invoices and payment events
    inventory/
    reporting/
    messaging/
    administration/
    patient_portal/
    public_site/
    subscription/
  l10n/                     # retain ARB and generated localization pipeline
```

This is the target, not a mass file move. Initially a `LegacyPatientRemoteSource` wraps existing service calls. Move serializers, validation and transaction behavior once their characterization tests exist. Remove a legacy path only when its migrated feature is equivalent. Session scopes cancel subscriptions and sync workers on account/clinic changes; do not retarget a queued operation using mutable `activeClinicId`.

Define save outcomes explicitly: `savedLocally(operationId)`, `confirmed(serverRevision)`, `needsReview(conflict)`, `rejected(reason)`. Avoid `Future<void>` for workflows whose local and remote completion have different meanings. Use sealed immutable presentation states for loading, cached, empty, ready, pending, conflicted and failed, with the underlying cached data retained during refresh failures.

## Firebase integration and desktop feasibility

Keep `firebase_options.dart`, application registrations, existing collection names and the current project. Preserve `users`, `clinics/{clinicId}/...`, legacy stock mappings, private notes, templates, invitation/notification contracts and existing module checks. Audit deployed rules/indexes before additive migrations; no destructive schema conversion is part of the initial UI work.

Firebase's current Flutter documentation cautions that Windows support is intended for local development rather than production and lists no native Linux implementation. Firestore persistent offline support is documented for Android, Apple and web. These are transport constraints, not Flutter layout constraints. [Firebase plugin support](https://firebase.google.com/docs/flutter/setup), [Firestore offline persistence](https://firebase.google.com/docs/firestore/manage-data/enable-offline).

| Target | Proposed remote access | Durable local state |
| --- | --- | --- |
| Web, Android, iOS, macOS | Keep existing FlutterFire Auth/Firestore where supported; use authenticated HTTPS commands for protected sync workflows | Shared Drift database, with platform-specific database opening only |
| Windows, Linux | Production-targeted Dart HTTP adapter for Firebase Auth/Firestore REST and the same command API; verify every required auth flow and token lifecycle in the foundation spike | Drift native SQLite |

Firebase Auth offers REST endpoints and Firestore REST accepts Firebase ID tokens evaluated by Security Rules. This supports retaining the existing backend and identities. It does **not** automatically supply native snapshot listeners, local caching, secure token storage or every phone/MFA flow. Implement a common change-feed/pull interface, reconnect backoff and refresh; validate a system-browser verification flow for phone/MFA where the platform needs it. A browser fallback alone does not meet the requested native Linux release. [Auth REST](https://firebase.google.com/docs/reference/rest/auth), [Firestore REST authorization](https://firebase.google.com/docs/firestore/use-rest-api).

New authenticated command handlers in the existing Functions project should perform revision checks and idempotent multi-document work. If using Admin SDK they bypass Firestore rules, so they must independently enforce identity, clinic membership, module, clinical assignment, field permissions and capability. Reuse a server authorization policy and test it against the rules contract. Never put service-account credentials in Flutter. App Check for desktop is an explicit feasibility item; do not disable enforcement merely to make a desktop request pass.

To honor the Figma role model without breaking existing accounts: retain stored role strings, map them through an explicit compatibility policy, inventory current grants, then introduce granular billing/admin/clinical-assignment capabilities through a reviewed migration. Unknown roles should fail closed. Do not let a Doctor/Staff/Patient UI tab alter privileges. Pharmacy, vaccinator, accountant, manager and Platform Owner workspaces remain supported. Changes that narrow legacy access need migration coverage, not silent UI-only restrictions.

For staff-readable patient data, split protected clinical details into an appropriately restricted record/projection with additive migration. Firestore rules cannot hide individual fields of a readable document. Patient access must resolve through a verified UID-to-patient association; shared phone numbers or matching names are not an identity mapping. Release only a deliberate patient-facing projection and keep private notes excluded.

Storage work should use the existing verified bucket, clinic/patient/document metadata, upload limits and access rules. Queue attachment metadata and protected local bytes separately, upload idempotently, then link the verified object to the record. Consent-driven notifications remain server-side and occur after accepted commands; failed delivery must not repeat the underlying clinical/payment action.

## Offline-first data and synchronization

### Local store

Recommend **Drift over SQLite**, using native SQLite on Android/iOS/Windows/macOS/Linux and a WASM-backed database on web. This provides typed queries, transactions and schema migrations with shared repository code. Evaluate database size, encryption, browser persistence and worker packaging in Phase 1 before committing a package version. shared_preferences remains appropriate only for nonsensitive UI preferences. [Drift platform support](https://drift.simonbinder.eu/platforms/).

Web persistence has browser-specific fallbacks, including memory-only or unsafe multi-tab modes. Detect the selected persistence mode, coordinate a single sync writer across tabs, and do not advertise restart durability when only memory storage exists. Cache the Flutter application shell, fonts, WASM and worker assets explicitly for repeat offline launch; test update/rollback and OAuth compatibility with hosting headers. First-ever use still needs installation/download and authentication. [Drift web setup and storage modes](https://drift.simonbinder.eu/platforms/web/).

The local schema needs feature tables plus `outbox_operations`, `sync_cursors`, `conflicts`, `attachment_jobs` and scoped access metadata. Partition by Firebase project, user and clinic. Maintain a server-confirmed base and pending local overlay so a remote snapshot cannot erase unsynchronized edits. Bound downloaded data to authorized patients, recent/relevant work and explicitly available history; show when search results are limited to cached data. Persist local data and its outbox operation in **one database transaction**; show saved only after that transaction succeeds.

Outbox fields: stable operation ID, schema version, UID, clinic ID, entity ID/type, intent/payload or field patch, base server revision, dependency IDs, client timestamp, retry count, next-attempt time, state and sanitized failure. Generate stable entity IDs before the first save, reuse them after retry, and order dependent work (patient before linked visit, file before release). Use server timestamps for authoritative ordering, not the device clock.

### Delivery protocol

1. Repository serves local data immediately, marked with freshness/sync state. Local validation and capability checks apply before accepting a draft.
2. The local transaction saves the draft/overlay and enqueues the command. Offline users see **Saved on this device — pending sync**.
3. A scoped worker starts at sign-in/unlock, app start/resume, reconnect and manual retry. Connectivity is only a hint; request outcomes establish reachability. Use a lease to recover interrupted in-flight work and avoid multiple concurrent workers.
4. Send the same operation ID with a refreshed Firebase ID token. Server revalidates current grants, expected revision and invariants. It commits the business change, idempotency receipt and change event atomically, or returns a typed conflict/rejection.
5. On a lost response, resend the same ID or query its receipt. Repeating an increment, stock movement, payment, reminder or message must not repeat the effect. Reject reuse of an operation ID with a different payload.
6. Apply acknowledgement and remove the corresponding pending overlay in one local transaction. A timeout leaves an operation uncertain/pending, not confirmed or discarded.
7. Pull authorized deltas with a stable cursor and deterministic ordering. Persist each page and cursor atomically. Handle removals, unsharing and membership revocation explicitly; bounded-query omission is not deletion. Reconcile after cursor expiry or incomplete bootstrap. Use a server-managed change/tombstone feed for eventual catch-up on desktop.
8. Retry transient failures with capped exponential backoff and jitter. Pause authentication failures for reauthentication; retain validation/permission errors and conflicts for action. Do not spin or continually retry a permanent rejection.

The accepted command path must be the single write authority for a migrated workflow. Firestore's own cache can remain a read optimization, but do not also enqueue the same write through its SDK. During migration, leave an unmigrated feature on its old writer until cutover. Reliable revision/conflict guarantees require all writers, including older clients and administrative jobs, to participate. Backfill metadata, enforce a minimum compatible client for migrated writes and test old-client behavior; asynchronous triggers alone are not atomic revision enforcement.

Proposed additive server artifacts include operation receipts, synchronization metadata/change records, release versions and reservation records. Final collection names and retention are design decisions for implementation; they must be covered by rules, indexes, emulator tests and rollout procedures. Existing business documents remain at their current paths. Hard deletes from legacy clients need reconciliation during transition; migrated deletes should produce tombstones. Purge only after a defined retention/cursor policy, with full resync for devices returning after that horizon.

### Conflict and offline policy

Firestore uses last-write-wins for competing document changes, and client transactions fail offline. These defaults are insufficient for the clinical and financial workflows here. [Offline behavior](https://firebase.google.com/docs/firestore/manage-data/enable-offline), [transaction behavior](https://firebase.google.com/docs/firestore/manage-data/transactions).

| Data/action | Offline behavior | Server reconciliation |
| --- | --- | --- |
| Previously synchronized records | Read/search within the user's retained scope; show age/coverage | Refresh base version and permissions; never expose another user's partition |
| Patient registration/demographic edits | Durable local draft/provisional record | Stable ID; duplicate review; non-overlapping fields may merge only when the base is unchanged for those fields; overlapping edits require review |
| Clinical drafts, lab/vaccination entry drafts | Create/edit locally with clear pending state | Compare base revisions; preserve both conflicting versions for clinician resolution; no automatic medical-text merge |
| Signed notes, issued prescriptions and patient release | Read cached accepted versions; prepare changes as drafts | Online authorization and immutable version/amendment workflow; never silently rewrite a signed record |
| Booking, reschedule, cancellation, queue transitions | Save requests/intents; show pending and retain known confirmed state | Recheck status/assignment and serialize interval reservations by clinic, clinician and date; a stale local slot is never a confirmation |
| Stock movements and sale | Save a proposed movement | Idempotent server transaction checks balance and applies linked invoice; do not claim stock is reserved while offline |
| Invoice draft / cash collection note | Keep durable draft/provisional collection note | Reconcile against payment events; accepted ledger determines paid balance/receipt; no last-write-wins amount replacement |
| Online payment/subscription activation | Show cached invoice and draft review | Online only; verify provider status/webhooks; manual collection and online settlement cannot settle the same balance twice |
| Messages/reminders/uploads | Durable draft or queued item with delivery state | Dedupe, revalidate recipient/consent, then dispatch/upload; no sent/delivered claim before acknowledgement |
| Eligible deletion | Hide locally with an undoable pending-delete state | Revision check; delete-versus-edit conflict is surfaced. Signed clinical/financial data follow archive/amendment policy, not generic deletion |
| Sign-in, OTP/MFA, team/role changes, AI processing | Show cached permitted data or save safe form drafts | Fresh verification/online processing required; no new identity or privilege granted offline |

Server reservations must cover the complete visit interval, including variable durations and breaks. The model needs clinician ID, visit type, start/end or duration, timezone and schedule revision. Serialize conflicting schedule changes with booking acceptance. A reschedule request retains the original confirmed booking until a replacement is accepted atomically. No-show, cancellation and completion are separate transitions with appropriate author/reason/timestamps.

### Local confidentiality and operational limits

Use platform-backed key/credential storage and encrypted clinical payloads or a validated encrypted database implementation on native targets. Drift by itself is not an encryption guarantee. Never store auth refresh tokens or clinical records in shared_preferences. Web persistent health data requires an explicit trusted-device choice and an unlock/key strategy; in-app encryption does not protect an already unlocked browser from malicious same-origin scripts. Provide an ephemeral shared-device mode and a visible durability limit when persistence is unavailable.

Lock and unmount patient UI on logout/session expiry. Never replay user A's queue as user B. Offer a controlled choice to retain encrypted pending work for the same user's next unlock or explicitly discard it; do not silently erase unsynced work. Revalidate membership before upload after reconnect, quarantine rejected work, and remove access to revoked/unshared data. Cached authorization cannot learn revocation while disconnected; define a bounded offline-access lease and require online revalidation after expiry. The offline lease/retention policy needs product agreement before production rollout.

Sync automatically while the app is running and on resume/reconnect. Mobile operating systems and closed browser tabs do not guarantee execution; background jobs are an optimization, not the only path to delivery. Attachment download availability and durable saves must be visible separately. Show aggregate pending/error counts from the outbox and per-record state, plus separate last-download and last-upload times.

## Phased implementation and acceptance

Implementation update (28 October 2026): Phase 2 now includes the Figma front-desk/arrival UI and encrypted durable booking replay. See [Phase 2 implementation and rollout limits](phase-2-operational-slice.md). Scheduling cutover remains disabled; native desktop runtime qualification, the production Linux Firebase adapter and the broader clinical/offline migration are not declared complete.

Implementation update (29 October 2026): the core Phase 3 patient → consultation → prescription review/sign → issued/release/amendment flow is implemented behind the server-managed `clinical_v3` pilot gate, with encrypted device recovery and immutable signed versions. See [Phase 3 clinical implementation and validation](phase-3-clinical-workspace.md). Production cutover, native qualification, lab-order/requisition migration and independent care-plan release are not declared complete.

Phases are ordered by dependency and are not delivery-date promises. Each phase includes widget, repository and integration checks for the features it changes.

| Phase | Deliverable | Exit evidence |
| --- | --- | --- |
| P0 — assessment | This plan, 59-node mapping, preserved-feature inventory, documented design differences | Scope and architecture are reviewable; baseline test limitations recorded |
| P1 — foundations and feasibility | Figma tokens/assets, adaptive shell/route model, repository contracts, scoped session, Drift migration/outbox prototype, desktop Auth/remote adapter, web offline bootstrap | Native Windows/Linux sign-in + authorized read; durable local save/restart/replay; same-user isolation and web multi-tab tests; no sensitive SDK/config replacement |
| P2 — operational vertical slice | Staff directory → registration/review → administrative profile → scheduling/queue; physician schedule; existing pharmacy workflows retained | Offline draft survives restart; duplicate/race tests; atomic practitioner interval reservation; no false confirmed booking; original IDs, legacy data and roles still work |
| P3 — clinical workspace | Patient overview → consultation → review/sign → issued Rx/release; labs/requisitions; treatment/vaccination; retained prescription templates and printing | Signed versions immutable; private notes excluded from portal/PDF; conflicting drafts preserved; patient/clinic/assignment boundaries tested; localization and print checks |
| P4 — patient portal and messaging | Own records, bookings, request tracking, consent/profile correction, patient/doctor/staff message routing; verified phone access | No cross-patient reads; OTP linked to verified patient identity; original booking retained through reschedule requests; idempotent message retry; cached data scoped correctly |
| P5 — administration and public journeys | Setup wizard, capability settings, clinic/team management, preferences/security/access states, reports, public Flutter pages, directory and real QR destination | Existing admin and specialist workflows preserved; public fields contain no patient data; draft setup does not publish; genuine empty/loading/error states; deep links/reloads verified |
| P6 — commerce and assisted workflows | Encounter payment ledger/verification/receipts, separate subscription domain, AI PDF review/source verification and decision-support drafts | Provider/webhook dedupe, no duplicate settlement, configured commercial terms, reviewed AI output only, protected Storage and platform-specific auth/App Check validation |
| P7 — production qualification | All 59 references completed or explicitly blocked by missing product/service decisions; cross-platform regression, migration rehearsal, performance and release packaging | Six target build/runtime suites; signed-device checks; browser offline cold-start; recovery and rollback rehearsal; documented release acceptance per feature |

Preserve optional purchased-module gates at every phase. Roll out by feature and pilot clinic using configuration flags; keep one writer active per feature. Release compatible server endpoints/rules/indexes before clients that need them, then migrate metadata in restartable batches with counts and rollback evidence. Old UI can remain for unmigrated workflows, but must not bypass new invariants after a feature switches writers. Rollback must preserve pending outbox operations and additive metadata; do not restore an incompatible writer against signed/payment records.

Production checks must include airplane-mode create/edit/delete + restart, lost acknowledgement, concurrent devices editing one record, clock skew, duplicate uploads, revoked access, clinic switching during save, expired credentials, browser quota/eviction/private mode, multiple tabs, offline app-shell launch, returning after tombstone retention, and rejected server writes. Use synthetic records and the Firebase Emulator Suite. Existing source tests provide a starting point; expand CI from selected-file analysis to the migrated application and include currently separate rules/delivery suites as appropriate.

Responsive acceptance covers 320/390/600/768/960/1200/1512 widths, landscape and keyboard-open forms, English/Hindi/Gujarati, 200% text scale and keyboard-only navigation. Test realistic paginated datasets and measure startup, frame rendering, sync backlog throughput and memory on representative mobile and desktop devices before claiming smooth performance. Build success is not equivalent to Firebase runtime support, signing, printing or offline correctness.

## Product decisions and design ambiguities to resolve during implementation

- The plan assumes **Uvilo UI branding**, because it is explicit in the supplied design. Legal/company identifiers, app-store naming and deployment domains remain separate decisions.
- Frame 28 contains text claiming AI is included in Free, while the primary plan matrix (24) and later subscription/setup frames place AI on Solo and above. Use one centrally configured entitlement model; resolve this discrepancy before implementing billing gates. Do not copy contradictory text into production.
- Current roles include clinic administrators with broad access and specialist operators absent from Figma's three product-role presentation. Define the explicit legacy-to-capability migration and clinical-assignment rules; do not infer role changes from the design alone.
- Figma's 20-minute, multi-session practitioner schedule differs from the current 15-minute slot UI. Agree visit types, durations, fees, breaks, holidays and booking-request policy before reservation migration.
- Payment gateway, production subscription prices/record-count definition, taxes, cancellation/refund/proration terms and support routing are not established by a static sample. Frame 51 explicitly leaves the final charge unresolved. Implement the review states, but do not activate invented commercial rules.
- Identity linking for patient phone access, desktop phone/MFA flow, offline lease length, encryption/key recovery, retention and trusted-device policy need concrete product and infrastructure decisions.
- Legal/support/publication content includes pending-review and illustrative contact data. Retain readiness states until real content/configuration exists; a design's sample readiness notice is not evidence about deployed legal policy.

These decisions do not prevent the foundation and existing-feature visual migration. They do prevent claiming the affected new workflows are production-ready before their contracts, configuration and acceptance tests are complete.

## Phase 3 continuation — 29 October 2026

The clinical workspace, consultation/prescription lifecycle, manual lab/requisition/result and care-plan release flows now have local implementations and synthetic validation. See [the Phase 3 implementation report](phase-3-clinical-workspace.md) for contracts, default-off pilot flags, evidence and release limits. Original laboratory, treatment and vaccination workflows remain available; no production rollout or automatic legacy author assignment occurred.

Remaining qualification includes Windows toolchain/symlink setup, Linux runtime/Firebase support, remote desktop CI execution, representative-device performance/printing, offline authorization/key-retention policy and a migration rehearsal. AI result extraction remains P6. Patient/public journeys, administration and commerce remain governed by the phase table; this continuation does not mark all 59 references complete. SMS testing remains on hold until DLT approval.

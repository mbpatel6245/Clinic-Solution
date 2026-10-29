# Phase 2 operational slice

Implementation status: 28 October 2026. This is a tested, additive migration slice in the working tree. No Functions, rules, clinic flags or production Firebase configuration were deployed or changed remotely.

## Implemented

- The production home workspace uses the adaptive Uvilo shell, preserving the existing role/module destinations, clinic switch, language, profile and sign-out actions.
- The patient directory uses real records, search, deterministic pagination and actual counts. It adapts from an administrative table to mobile cards. Existing identifiers and clinical workspaces are retained.
- New registration requires care consent and a separate review of potential matches. Shared phone numbers are hints, not identity proof; records are never automatically merged. The existing registration transaction and stable IDs remain the save path.
- The administrative profile limits its presentation to identity, contact, address, consent preferences and appointments. Contact edits check the previous contact/address values and atomically record a reason and audit entry. Registration/review/contact-edit dialogs hide their contents when their captured account/clinic access changes.
- Registration drafts have explicit encrypted Save/Restore actions. AES-256-GCM, a fresh salt/nonce and PBKDF2-HMAC-SHA256 with 600,000 iterations protect the payload; no passphrase/key is stored. The project/user/clinic scope is authenticated additional data. SQLite revision checks reject stale-tab overwrites, including after removal/recreation: removal clears the encrypted envelope and retains only the scope/revision tombstone. Restoring a draft does not skip consent/review or confirm a patient registration.
- A repository-driven practitioner day/week schedule, appointment form and own-availability editor are available to clinics with `operational_v2: true`. The existing booking screen remains the default elsewhere.
- New server commands validate current membership, role, module access, clinic hours, practitioner and patient identity. A Firestore transaction serializes each clinic/day, checks the whole visit interval, and writes the appointment, audit and operation receipt together. Lost acknowledgements can retry the same ID/payload. Changed payloads cannot reuse an accepted ID. Adjacent visits are allowed; overlaps and intervals crossing a working-session boundary or timezone transition are rejected.
- The arrival action reviews identity and records an independent arrival acknowledgement. Migrated clinics use the server command; other clinics keep the existing workflow.
- The reception-only home now opens a Figma-based front-desk overview. It shares responsive appointment tables/cards, metrics, queue, activity and quick-action panels with the arrival workspace. Billing summaries follow actual role/module access and are labeled as collections against invoices issued today because the existing schema has no payment-event timestamps. Arrival times come from recorded fields; tokens and consultation timestamps are never invented.
- The arrival workspace includes name/ID and contact checks plus independent arrival consent, bound to the selected appointment's identity. Search/selection changes cannot reuse another patient's acknowledgements. Legacy arrival updates now record arrival/audit data atomically; migrated clinics retain the server writer. No-show review requires a reason and clinic acknowledgement, rejects already arrived patients and future bookings, and records an audit entry. Migrated rules enforce the arrived/future safeguards too.
- Booking requests are committed to an encrypted local journal before network submission. The unlocked workspace retries with backoff every 15 seconds and on app resume. It restores pending/uncertain requests after restart and reuses the exact operation ID/payload. Database leases serialize workers across connections/tabs; server receipts remain the final deduplication authority.

## Figma references and adaptation

The supplied file is `R0viGL5IhmGCMiTAf99Mxn`. Full context and screenshots were reviewed for patient directory `4:18003`, registration `4:18237`, scheduling `4:18438`, queue/check-in `12:4553`, duplicate review `46:50868`, administrative profile `46:50978`, physician availability `46:51088` and front desk `4:17763`.

The implementation reuses the exported Uvilo mark, Inter font, teal palette, 216-pixel desktop navigation, bordered panels and supplied icons. The 109 downloaded SVGs are local in `assets/figma/phase2/`; all are nonempty SVG documents. Temporary Figma asset URLs are not used at runtime.

Synthetic visual review artifacts are in `build/phase2-review/`, with `directory`, `profile` and `schedule` images at 390 and 1512 pixels. At narrow widths the directory uses cards, navigation uses a drawer/bottom destinations, booking controls stack, and the week calendar scrolls horizontally. Text scaling can force the compact shell even on wide screens. Counts and empty states describe actual data rather than copying Figma's sample totals.

Registration deliberately continues through the existing responsive dialog and transaction, with an added review step. The front-desk overview and queue now use the supplied Figma composition and local assets, adapted for actual clinic permissions/data and compact screens. Notification tasks that would send unconfigured messages are replaced by real queue/billing navigation. These are functional adaptations, not completed pixel-for-pixel reproductions of every referenced frame. The full 59-screen migration is not complete.

## Validation

| Check | Result |
| --- | --- |
| Full Flutter regression | 196 tests passed, including existing intake, patient, clinical, prescription and treatment workflows |
| Final booking-stream check | 6 focused schedule tests passed, including the added case where a selected patient disappears; new booking is disabled without crashing the form |
| Scoped static analysis | No issues in the new features, shell, integrated home/intake/booking/profile views, models, service, preview and Phase 2 tests |
| Backend TypeScript and unit tests | Compilation passed; 33 tests passed |
| Firestore Emulator Suite | 16 tests passed: 7 operational command tests and 9 clinic/rule tests |
| Race and retry cases | Concurrent overlap, adjacent intervals, lost acknowledgement, operation payload mismatch, closed day, short session, revoked membership, migration gate, legacy unassigned visits, arrival acknowledgements/idempotence and DST transition covered |
| Draft and booking recovery | Real SQLite files closed/reopened; encrypted payloads, wrong passphrase, scope isolation, stale draft revision/removal, lost booking acknowledgement, immutable payload, separate-connection leases, expired lease/stale acknowledgement, access pause and permanent rejection covered |
| Responsive widgets | Directory/profile and front-desk overview/queue at 320/768/1512, English/Hindi/Gujarati with 200% text; schedule at 320/768/1512 with 200% text; arrival acknowledgements, uncertain-booking retry and dialog access-change checks |
| Visual QA | Desktop and mobile synthetic directory, profile, schedule, front-desk and queue images inspected; navigation font, input borders, table geometry and mobile week-view behavior corrected |
| Browser booking recovery | Synthetic encrypted request survived a cold reload with the HTTP server stopped; after unlock, automatic replay against the simulated transport confirmed the same request ID/interval |
| Production web release | `lib/main.dart` compiled successfully with local web resources; no Firebase deployment performed |

The complete Flutter test log is `build/phase2-complete-regression.log`. The latest analysis is `build/phase2-extension-analyze-final.log`, emulator results are in `build/phase2-extension-emulator.log`, Windows native storage/HTTP checks are in `build/phase2-windows-native-probe.log`, and toolchain/build diagnostics are in `build/phase2-desktop-doctor.log`, `phase2-windows-build.log` and `phase2-linux-build.log`. Build results and environment limits are not inferred from test success.

## Durable offline booking lifecycle

The production booking workspace for migrated clinics requires unlocking the local booking vault. A user-selected passphrase of at least 16 characters derives a key using PBKDF2-HMAC-SHA256 (600,000 iterations); only the salt and authenticated verifier are persisted. Each request/cache value uses AES-256-GCM with a fresh nonce and scope/type/request ID in authenticated additional data. Keys are retained only in the unlocked workspace's memory. The database is `uvilo_booking_outbox_v1`, separate from both legacy caches and the synthetic Phase 1 database.

1. Persist a frozen booking command locally, then show **saved on this device**, not confirmed.
2. Claim a 60-second lease and persist the uncertain state before calling the existing authenticated command endpoint. Client HTTP/request timeouts are shorter than the lease.
3. Mark confirmed only after the server acknowledges `booked`. A crash or lost response retains the original request for receipt-based replay. Another worker cannot acknowledge a lease it does not own.
4. Retry transient/ambiguous failures with capped exponential backoff and jitter. Pause authentication/permission failures for explicit access review. Keep permanent conflicts/rejections visible; do not alter and resend their accepted operation ID.
5. Restore the journal after reopening and unlocking with the same passphrase. While open/unlocked, polling and app resume trigger synchronization. Closed apps/tabs do not promise background execution.

Patient-choice caches contain only IDs/names; practitioner choices contain IDs/names. They are encrypted in the same vault and are restored offline only from a roster snapshot validated within the last 24 hours. Cached Firestore emissions do not extend that cache window while offline. This is a cache-load limit, not an offline authorization lease or automatic lock of an already unlocked screen. The server always revalidates access, clinic hours, patient/practitioner records and interval availability when replaying a request. An expired cache does not discard pending work.

The passphrase cannot be recovered by the app. There is no silent plaintext fallback when durable browser storage is unavailable. Pending work is not automatically deleted or transferred to a different account/clinic on logout. UI state is unmounted/locked on scope changes. This implements durable booking requests, not a general-purpose offline clinical repository or a claim that disconnected booking guarantees availability.

Browser verification used `tool/booking_sync_preview.dart` in the connected Chromium browser. Request `synthetic-1793190309659000-0` retained `2026-10-29T03:30:00.000Z` and 20 minutes after the local HTTP server was stopped and the cached app was reloaded. Unlock restored **awaiting confirmation**; switching the synthetic transport online led to **confirmed** automatically. Another cold reload with the simulated transport offline retained the confirmation. Evidence: `build/phase2-review/booking-browser-restored.png` and `booking-browser-confirmed.png`. This tests browser storage, app-shell recovery and client replay; it is not a live Firebase booking. Firestore transaction/rule behavior was tested separately in the emulator. The service worker used here is restricted to isolated synthetic build outputs; no production Hosting/cache policy was changed.

## Deployment and pilot migration

1. Keep `operational_v2` absent/false while qualifying the migration. The property is server managed and is not exposed by the clinic settings serializer.
2. Deploy and validate the additive `operationalCommand` and `operationalPractitioners` functions in `asia-south1`, and the corresponding rules, in a nonproduction environment first. Retain the existing Firebase project/configuration. Rehearse rollback there.
3. Inventory future appointments. Review practitioner assignments, durations, clinic timezone, opening/closing times and working days. Legacy unassigned appointments conservatively block every practitioner for their interval; they must be explicitly reviewed before a pilot.
4. Test staff and doctor accounts against the pilot's real role/module configuration. Only an approved doctor can edit their own availability. Test reception arrival and existing clinical completion/cancellation paths too.
5. Require compatible clients before enabling the clinic flag. Migrated rules reject legacy direct appointment creation/deletion and interval/practitioner changes; only supported completion/cancellation/no-show status updates remain on the existing writer. Old public/portal booking and rescheduling clients must be migrated before their clinic is enabled. Do not toggle an active clinic as a casual UI preview.
6. Enable one reviewed pilot clinic only after these checks. Observe rejection/conflict rates and reconcile uncertain results using the accepted operation receipt and appointment before initiating a different request.

No pilot clinic was enabled during this task. CI now includes operational emulator cases and the existing Windows/Linux/native build jobs; remote CI has not been executed by this session.

## Remaining qualification and limitations

- Booking requests now have an encrypted restart-safe outbox and automatic replay while open/unlocked. Server deployment, compatible client migration and the per-clinic gate are still prerequisites for using the new booking writer. Registration drafts remain offline documents, not reservations or automatically synchronized patient records.
- Availability updates preserve all booked intervals, but two independent availability editors currently use last accepted write semantics. Field-level conflict review/revision preconditions and a durable reconciliation UI remain to be implemented.
- Registration-draft encryption does not supply key recovery, an offline authorization lease, platform credential storage, automatic draft retention/expiry, or protection for an already unlocked browser. Production offline clinical synchronization and attachment caching remain later migration work. Phase 1's unencrypted synthetic database is not used for production patient drafts.
- The new encrypted draft store has native file-reopen coverage. Phase 1 separately verified browser durability/multiple tabs; the new encrypted registration UI still needs an end-to-end browser restart/multiple-tab qualification.
- Windows GUI packaging remains blocked locally by missing Developer Mode/plugin symlink privileges and Visual Studio C++ tools. Linux GUI/runtime testing remains unavailable locally because no Linux/WSL distribution is installed. Native SQLite tests on Windows and configured CI do not establish six-platform production readiness. Desktop Firebase sign-in/refresh and unsupported Linux plugin paths still need real runtime validation.
- The front-desk visual migration is implemented and responsive checks pass. Complete device performance checks, broader keyboard/screen-reader journeys and signed native release qualification before declaring Phase 2 production ready. Clinical notes and financial records retain their existing workflows.

Windows validation re-ran the seven native SQLite/HTTP feasibility checks successfully. Actual Windows package building still fails at plugin symlink support, and Flutter Doctor confirms Visual Studio is not installed. The Linux build command correctly refuses this Windows host; no WSL distribution is available. More importantly, production `DefaultFirebaseOptions.currentPlatform` explicitly throws on Linux. Re-running FlutterFire alone does not supply unsupported native Firebase plugins: a production Linux Auth/Firestore adapter and real sign-in/read/write qualification remain necessary. Existing Firebase configuration has deliberately been preserved.

`.github/workflows/foundation-ci.yml` now builds and launches the synthetic Phase 2 native renderer on Windows and Linux (Linux uses Xvfb and both runs have a 30-second bound). `tool/phase2_desktop_smoke.dart` exits nonzero on Flutter render errors. These checks are configured but have not run remotely, and the synthetic renderer does not qualify production Firebase runtime support.

## Messaging

SMS testing stays on hold until an approved DLT sender/template is available, as requested. The earlier synthetic MSG91 email was delivered; see `msg91-test-setup.md`. No new SMS or email was sent as part of Phase 2, and the global notification gate remains disabled.

## Local reproduction

Use the project's resolved Flutter SDK/dependencies:

```text
flutter test
flutter test --dart-define=PHASE2_SCREENSHOTS=true test/phase2/visual_review_test.dart
flutter run -t tool/phase2_preview.dart -d chrome
flutter run -t tool/booking_sync_preview.dart -d chrome
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn
npm test --prefix functions
```

The preview is synthetic and does not initialize Firebase. Its scheduling adapter deliberately refuses writes. Run emulator tests only with `FIRESTORE_EMULATOR_HOST` set to a local emulator; their project IDs are `demo-clinic-operations` and `demo-clinic-revamp`.

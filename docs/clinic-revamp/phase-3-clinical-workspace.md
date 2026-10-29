# Phase 3 — clinical workspace and prescription flows

Implementation: 28–29 October 2026. Local implementation and synthetic validation; no production deployment, clinic flag change, Firebase configuration replacement or MSG91 transaction was performed. SMS testing remains on hold pending DLT approval.

## Implemented scope

The existing patient record, consultation editor, prescription templates, private-note handling, queue integration and multilingual PDF service are reused. The core references are Figma nodes `2:1192` (patient overview), `4:18715` (consultation), `4:18896` (prescription review), `46:51259` (review/sign/complete) and `46:51392` (issued prescription/sharing), in file `R0viGL5IhmGCMiTAf99Mxn`.

- Patient overview uses actual patient-ID-matched visits, diagnoses, latest recorded measurements and medicines, allergies, contact information and follow-up. No sample measurements, graphs or inferred clinical targets enter production defaults.
- Consultation uses the Uvilo theme, patient/encounter banner, allergy warning, a desktop context column and separate visit-note and assessment/plan panels. Smaller layouts stack these panels. Existing medication, investigation, advice, template and private-note fields remain available.
- Legacy saves open a review screen with independent identity, medication and plan checks. New patient sharing defaults off; existing sharing settings are retained when editing a legacy record. A save message distinguishes a queued Firebase write from server-confirmed signing.
- Migrated clinics have online draft save → four-acknowledgement review → immutable sign/queue completion → issued record → independent patient release, access revocation and audited amendment. The same clinician can discover saved drafts and view/print immutable version history.
- New signing/release/revocation errors remain unconfirmed. Reload retrieves server state; signing never runs automatically on reconnect. Same-operation retries retain their operation ID in the open flow, and server revision checks prevent duplicate finalization across restarts.
- PDF output identifies signed version numbers and uses the clinic/practitioner print context captured at signing. An unrelated clinic letterhead cannot substitute another practitioner's registration. Private notes and internal account identifiers remain excluded. Frozen signed copies can render without fetching mutable clinic settings.

The manual lab-order/requisition, reviewed-result and independent care-plan release flows are now implemented from Figma nodes `4:19096`, `46:51527`, `22:10739` and `46:51772`, behind the separate default-off `clinical_artifacts_v1` pilot. Original laboratory, treatment-sitting and vaccination screens remain reachable. AI source-PDF ingestion/extraction is still Phase 6 work; no automated clinical verification is represented as completed.

## Lab and care-plan extension

Wide layouts provide a document list and selected preview; narrow layouts use stacked navigation and review. The editor, patient banner, entered reference ranges, private recovery actions and review panel share the existing Uvilo tokens and original Figma SVGs at their native 16/18-pixel geometry. English, Hindi and Gujarati labels cover the new flows. Production clinical inputs start empty; synthetic records are isolated to tests and standalone renderer tools.

- Lab orders have separate draft, issued requisition, actual collection and cancellation transitions. Requested dates are distinct from actual collection timestamps. Printing never records collection. Collection requires its own acknowledgement, identifies the device timezone and records minute precision, practitioner and server audit time. Transaction guards prevent concurrent matching pending orders; a rejected duplicate draft is retained.
- Reports can identify a checked external source or link to the same practitioner's collected order. Report dates remain calendar dates. Numeric results require units and retain entered reference bounds; qualitative results stay text. Publication projects observations into the existing laboratory collection, and amendments supersede only the same document's previous projections. Immutable historic versions remain available. Entered reference ranges are not labelled as individual treatment targets.
- Care-plan copies select existing signed advice from the responsible practitioner's consultation and optionally existing treatment sittings and vaccination records for that patient. Source changes invalidate review. Publication does not change medicines, create a vaccination or confirm an appointment. Private plan/sitting notes, adverse-reaction notes and private source-verification notes are excluded from the rendered copy and PDF. Missing or unselected vaccination history is labelled unknown rather than unvaccinated.
- Four fresh acknowledgements and an online server response are required to issue a version. Patient release is separate and requires explicit consent, a verified linked recipient and the independent `share_clinical_artifacts_with_patients` setting. Amendments, cancellation, release and withdrawal preserve audit history. Unknown acknowledgements never become success; reload and return-to-draft guidance preserve the review boundary.
- Patient copies use scoped authorized clinic queries. Authentication, membership, sharing and read errors clear affected rows and open documents. Patient views never query practitioner drafts/private source notes. Disabling sharing withdraws existing copies; an interrupted cleanup is retried before re-enabling sharing so old copies cannot silently return. Administrators can read public copies for cleanup while sharing is off, but cannot read private author drafts.
- Frozen public snapshots produce multilingual PDFs with reviewed clinic/practitioner/patient context and version. Practitioners can open earlier immutable versions and release history. Printed/rendered fields exclude account identifiers and private verification notes; access-control metadata remains in the server-managed copy document.

`ClinicalArtifactRepository` separates presentation from the Firebase adapter. `clinicalArtifactCommand` in `asia-south1` validates approved responsible practitioners, explicit membership, enabled clinical/laboratory/vaccination modules as applicable, patient/source ownership, revision and complete operation digest. Client rules reject draft/public-copy fabrication, immutable version edits and manual changes to reviewed observation projections, including after a pilot rollback.

| Path beneath a clinic | Purpose |
| --- | --- |
| `clinical_artifacts/{id}` | Author-scoped draft input, sanitized record, frozen context, revision/version and order state |
| `clinical_artifacts/{id}/versions/{version}` | Immutable public snapshot and review acknowledgements |
| `clinical_artifacts/{id}/release_history/{event}` | Audited patient release/withdrawal and recipient |
| `clinical_artifact_copies/{id}` | Latest sanitized snapshot with separate patient-access flag |
| `clinical_artifact_receipts/{actor_operation}` | Idempotent command receipt bound to the complete request |
| `clinical_order_keys/{key}` | Server-only guard against concurrent matching pending orders |
| `laboratory/ca_{hash}` | Existing observation bridge with document/version provenance and supersession |

These paths and indexes are additive. Legacy records are not automatically assigned authors or claimed as reviewed. Care-plan publication needs an existing signed consultation source from the `clinical_v3` lifecycle. The lab protocol can be piloted independently when clinical and laboratory modules are enabled.

Lab/care recovery reuses encrypted SQLite with kind/document-specific scopes. Raw numeric/text input, dates, source selections, private verification, stable document ID and expected revision survive restart. Review acknowledgements and patient-release consent are not restored. Recovery/upload is explicit; there is no automatic offline issue/release or silent clinical conflict merge.

## Architecture and contracts

`lib/features/clinical/domain` contains recovery identity/repository contracts and clinical encounter/repository contracts. Data adapters wrap existing encrypted SQLite storage, scoped Firebase HTTP commands and consistent online transaction reads. Presentation components provide the shared clinical cards, responsive columns, allergy/identity banners, recovery controls, review and finalization screens. Existing Provider/ChangeNotifier composition is retained.

`clinicalCommand` is a new callable in `asia-south1`. Every transition revalidates an approved doctor/physician, explicit clinic membership, active clinic and clinical module availability. The server-managed clinic flag `clinical_v3` must be true. A responsible practitioner owns each encounter. A linked queue appointment must match that practitioner and patient; signing atomically completes an eligible confirmed visit. Existing legacy encounters cannot be claimed merely by supplying their ID.

The parent encounter revision serializes all writes. Changed patient identity or allergy information invalidates a signing review. Actor-scoped operation receipts bind an operation ID to the complete request digest; changed-payload reuse is rejected. Concurrent stale drafts are rejected without automatically merging clinical text. Public and private version documents use transaction `create`, never overwrite.

| Path beneath a clinic | Purpose |
| --- | --- |
| `clinical_encounters/{id}` | Responsible practitioner, patient/encounter identity, current draft, revision, version and release state |
| `clinical_encounters/{id}/versions/{version}` | Immutable signed public snapshot, review acknowledgements, amendment reason and signing metadata |
| `clinical_encounter_private/{id}` | Separate working private note, readable only by the responsible clinician |
| `clinical_encounter_private/{id}/versions/{version}` | Immutable private-note snapshot, never patient-readable |
| `prescriptions/{id}` | Existing collection: latest signed public projection, pharmacy status and explicit patient-sharing flag |
| `clinical_notes/{id}` | Existing latest-note compatibility path; signed-record notes are author restricted |
| `clinical_receipts/{actor_operation}` | Immutable digest/result for idempotent commands |
| `clinical_releases/{id_version}` | Immutable first-release acknowledgement and recipient |
| `clinical_release_revocations/{actor_operation}` | Audited withdrawal reason and time; signed clinical content remains intact |

Rules prevent client fabrication or editing of signed metadata and versions, including after a flag rollback. Existing pharmacy status updates are restricted to their operational fields on signed projections. Clinic administrators can clear sharing after disabling clinic sharing. Responsible clinicians can revoke an individual release without rewriting its signed version, including while an amendment is open.

Patient records now merge explicit authorized clinic queries rather than relying on an unbounded collection-group query. Membership changes, sharing changes, authentication changes and failed clinic reads clear the affected subscriptions and displayed rows. Additive indexes cover scoped patient queries and practitioner/patient draft discovery.

## Offline recovery

Clinical recovery reuses the existing SQLite AES-256-GCM/PBKDF2-SHA256 implementation: 600,000 derivation iterations, fresh salt/nonce, authenticated scope, no persisted passphrase, revision compare-and-swap and deletion tombstones. Clinical scopes are separate from registration scopes and include project, user, clinic, patient and encounter/new-consultation slot.

Save/restore is explicit, with a passphrase of at least 16 characters. Clinical fields, medicine instructions, private notes, stable record ID and server revision recover together. Restoring does not restore patient-release consent. A stale window cannot silently overwrite the recovery copy. Unsupported nondurable browser storage fails visibly. Recovery remains available when an existing encounter cannot be fetched online, and users can explicitly delete the device recovery copy.

Recovery is not an automatic clinical signing queue. Users must save their device copy before leaving the editor; unsaved keystrokes are not guaranteed after a crash. Legacy Firestore write queuing is retained. Migrated draft upload, signing, release and revocation need an online acknowledgement and fresh review. Recovery copies remain after clinic save until explicitly replaced/deleted. Browser eviction can remove local storage; an unlocked app cannot learn remote revocation while disconnected. A bounded offline authorization lease, OS credential vault and retention policy remain production qualification work from the original plan.

## Validation and platform limits

Evidence is saved under `build/phase3-*` (ignored generated artifacts):

- `phase3-full-tests-final.log`: **256 Flutter tests passed**, including Phase 1/2 regressions and the new recovery/clinical tests. Subsequent final sharing-control changes also receive focused flow tests.
- `phase3-final-flow-tests.log`: **62 checks passed** for final clinical/recovery, transport, scoped patient subscriptions, multilingual PDFs and screenshots.
- `phase3-editor-and-visual-final.log`: **2 further checks passed** for the migrated editor's complete draft → review → sign → Done flow and refreshed screenshots.
- `phase3-clinical-emulator-final.log`: **25 tests passed** for synthetic signing, draft races, immutable amendments, release/revocation, frozen print identity, scheduling and security rules. These tests refuse a non-loopback emulator address.
- `phase3-analyze-final.log` and `phase3-editor-analyze.log`: **no static-analysis issues**, including the changed application integration points and final editor integration test.
- `phase3-production-web-build-final.log`: **production `lib/main.dart` web release build passed**, including the Wasm dry run.
- `phase3-review/`: actual Flutter renders for mobile/desktop record, consultation, final review and signed screens. Responsive tests cover 320, 768 and 1512 widths, English/Hindi/Gujarati and 200% text.

Windows SQLite/encryption/restart tests run on this Windows host. The actual Windows renderer build stops because Developer Mode/symlink support is disabled; the earlier doctor check also found no Visual Studio C++ toolchain. The Linux renderer build cannot run on this Windows host, and no WSL distribution is installed. Windows/Linux CI now builds and runs `tool/phase3_desktop_smoke.dart` through all four synthetic clinical screens, but remote CI has not been run in this task. The production Linux Firebase runtime adapter is still unsupported. This is not six-platform production qualification.

## Controlled migration

1. Keep `clinical_v3` absent/false for current clinics. No client settings form serializes or enables it.
2. Review and deploy compatible functions, rules and additive indexes together before enabling a pilot. This task does not deploy them.
3. Use a synthetic pilot clinic with approved doctor accounts, explicit clinic memberships, registered patients and verified patient-account links. Queue visits need explicit practitioner assignments. Confirm practitioner names and matching clinic print settings.
4. Reconcile/export encrypted legacy drafts first. Existing editable prescriptions need an explicit reviewed migration if they must enter the new amendment lifecycle; no automatic author assignment or legacy record claim is implemented.
5. Exercise offline device save/restart/restore, two-editor conflicts, dropped acknowledgements, patient/allergy changes, release and withdrawal, account/clinic changes, queue completion, version printing and original pharmacy workflows before a production pilot.
6. Preserve signed version collections, receipts, private-note separation and signed-record rules during rollback. Do not re-enable a legacy writer against immutable records. Complete native runtime/Firebase and offline authorization qualification before claiming full Windows/Linux production support.

For the lab/care extension, keep `clinical_artifacts_v1` absent/false until compatible functions, rules and indexes are deployed and a synthetic pilot is accepted. Keep its independent sharing setting off until verified recipient links and withdrawal tests pass. Neither flag has been enabled by this task. Preserve immutable artifact and observation protection during rollback.

## Lab/care validation — 29 October 2026

- `build/phase3-artifact-all-tests.log`: **all 297 Flutter tests passed** in the final complete regression run, including the original application and Phase 1/2/3 checks. Nine synthetic lab/care PDFs were generated successfully across English/Hindi/Gujarati, and the final mobile/desktop screenshots were refreshed.
- `build/phase3-artifact-tests-final.log`: **41 focused Flutter checks passed** for review/release separation, lost acknowledgement, encrypted SQLite restart/CAS isolation, scoped sharing, HTTP failures and 27 document layouts at 320/768/1512 widths, English/Hindi/Gujarati and 200% text. The subsequent complete regression run includes another multilingual PDF-generation test and refreshed screenshots.
- `build/phase3-artifacts-emulator-final.log`: **32 local emulator checks passed**, combining lab/care, consultation signing, operational scheduling and security rules.
- `build/phase3-artifact-rules-final.log`: **11 final rules checks passed**, including administrative withdrawal-query access added after the combined run.
- `build/phase3-artifact-backend-unit.log`: **36 backend unit checks passed** and TypeScript compilation passed. Delivery tests use synthetic data/mocks and send no MSG91 transactions.
- `build/phase3-artifact-analyze-clean.log`: **no analyzer issues** across migrated features, integration points, renderer tools and Phase 3 tests.
- `build/phase3-artifact-production-web.log`: production `lib/main.dart` web release and Wasm dry run passed (**389.3 seconds**).
- `build/phase3-artifact-review/`: actual mobile/desktop lab requisition, report and care-plan review renders plus synthetic multilingual PDF samples. Desktop reports retain numeric/text results and entered ranges; mobile care plans stack the document and review panel.

Native qualification is still blocked: `phase3-artifact-windows-build.log` requires Developer Mode/symlink support, and `phase3-artifact-linux-build.log` rejects a Linux build on this Windows host. No WSL distribution was listed. CI now builds/runs the synthetic lab/care editor and review renderer on Windows and Linux, but those remote jobs have not run here. Production Linux Firebase runtime, desktop printing, offline authorization/key-retention policy, signed device packaging and representative-device performance remain unqualified.

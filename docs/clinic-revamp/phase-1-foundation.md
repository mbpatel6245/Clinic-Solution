# Phase 1 foundation — implementation and validation

Status: the responsive foundation and offline prototype are implemented as a separate, runnable sandbox. Production feature cutover, secure clinical storage and native desktop qualification are still pending. This is not a claim that the 59 screens or production Firestore synchronization are complete.

## Implemented

- Figma-derived Uvilo tokens, Inter font and supplied SVG identity, with reusable `AdaptiveWorkspace` and `AdaptiveContent` widgets. Widths below 600 use compact navigation; 600–1199 use a rail where height permits; 1200+ use the 216px sidebar. Large text switches to a drawer; mobile secondary content stacks; navigation avoids keyboard obstruction.
- Pure Dart patient repository and immutable project/user/clinic scope. Provider/ChangeNotifier remains the presentation approach. Existing routes, services and Firebase bootstrap retain their current behavior.
- Drift/SQLite local records and transactional outbox. Creating, updating or deleting a demo patient commits local state and its queued command atomically. Tombstones hide pending deletions. Confirmed revisions and queued states remain separate.
- Stable operation IDs, revision checks, durable simulated-server receipts, exponential retry, authentication suspension, permanent rejection, and explicit conflict review. The prototype allows one outstanding command per record. Review either adopts the server version or creates a new command against the server revision.
- A renewable database lease prevents competing workers from draining the same scope. Single-flight execution and disposal protect lifecycle transitions. Browser tabs refresh shared records. Download pages and cursors commit atomically; pages containing unresolved local commands remain replayable so later server changes cannot be skipped.
- A pure Dart Firebase Auth/Firestore REST feasibility adapter, plus a future authenticated sync-endpoint contract. Neither is installed in production. The synthetic server uses its own local database; the preview never calls Firebase.
- A separate web build preparation tool caches the preview shell, fonts, renderer, SQLite WASM and worker for repeat offline launch. It modifies only `build/foundation-web`, not the production web host or Firebase Hosting configuration. First use requires an online download. Cache eviction and private browsing can still remove availability.

## Run and review

Use Flutter 3.47.0 / Dart 3.13 as pinned by the existing project CI.

```sh
flutter pub get
flutter run -d windows -t tool/foundation_preview.dart
# On a configured Linux host:
flutter run -d linux -t tool/foundation_preview.dart

flutter test test/foundation
dart run tool/foundation_desktop_probe.dart

flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --pwa-strategy=none -t tool/foundation_preview.dart -o build/foundation-web
dart run tool/prepare_foundation_web.dart
```

Serve `build/foundation-web` at the root of a dedicated localhost origin or HTTPS test origin. Serve `.wasm` as `application/wasm` and `.js` as JavaScript. Do not host the sandbox under a production application's service-worker scope. The deprecated `--pwa-strategy=none` disables Flutter's legacy generated worker; the preparation tool supplies the preview's explicit static cache. New cache versions activate after older preview tabs close. No API responses are cached by this worker.

In the preview, leave the simulated server offline, add a demo record, restart/reload, then enable the simulated server. Confirm revision 1 and zero pending commands. Edit and delete only confirmed records. The UI accepts generated fixtures only. Its technical labels are for prototype review, not the final patient-facing design.

Optional rendered shell fixtures:

```sh
flutter test test/foundation/adaptive_workspace_test.dart --dart-define=FOUNDATION_SCREENSHOTS=true
```

Images are generated at `build/foundation-review/{390,768,1512}.png`. These are component review fixtures, not completed patient screens.

## Validation recorded on 27 October 2026

| Check | Evidence / limit |
| --- | --- |
| Original baseline | 122 tests passed before foundation changes |
| Full regression | Final 159 tests passed after the desktop dependency pin, including all 37 foundation tests |
| Final targeted foundation suite | 37 tests passed after adding malformed-download validation |
| Responsive layout | 320, 390, 600, 768, 960, 1200 and 1512 widths at 100% and 200% text; short landscape/keyboard; single/empty permitted navigation and mobile More |
| Durable native storage | Windows real-file reopen, lost-acknowledgement replay after simulated-server restart, and separate-connection lease exclusion passed |
| Desktop HTTP feasibility | Windows loopback Auth REST request and scoped bearer-token read passed; synthetic server only, not real Firebase or its Emulator Suite |
| Browser storage | In-app Chromium selected `sharedIndexedDb`; pending record survived reload with the local web server stopped, then synchronized through the simulated service |
| Browser multiple tabs | Second tab read the first tab's confirmed record; a second-tab save became confirmed and visible in the first tab |
| Release web builds | Preview and original `lib/main.dart` production entry point compiled successfully |
| Windows native app build | Blocked before compilation: system lacks plugin symlink privilege/Developer Mode and Visual Studio Desktop development with C++ |
| Linux native app/runtime | Not executed locally: no Linux/WSL distribution installed. New Windows/Linux CI builds the actual preview entry point and runs the native probe; remote CI has not been run from this session |

Windows/Linux CI is in `.github/workflows/foundation-ci.yml`; the existing production cross-platform workflow is preserved. Flutter tests and native SQLite running on Windows do not prove a Windows GUI package, native plugin runtime, Linux runtime, printing, or live Firebase authentication.

## Storage and backend contract limits

`path_provider_android` is pinned to 2.2.23, the release before the JNI migration, to avoid adding a JVM/native JNI build dependency to the desktop prototype. Reassess this pin when the newer dependency chain passes actual Windows and Linux package builds. The scoped foundation analyzer reported no issues.

Local sandbox files are named `uvilo_foundation_synthetic_v1` and `uvilo_foundation_synthetic_server_v1`; they are **unencrypted, synthetic-only**. Drift does not provide clinical-data confidentiality by itself. The `sqlcipher_flutter_libs` transitive EOL compatibility package does not enable encryption. Web memory-only storage is visibly labeled; an unsafe IndexedDB mode is refused.

Before routing real patient workflows through this foundation:

1. Add a platform-backed credential/key vault, encrypted native payloads, trusted-device/ephemeral browser policy, offline-access expiry, scoped unlock/logout and retention/revocation handling.
2. Implement and emulator-test the authenticated command endpoint in the existing Firebase project. Verify token identity, clinic membership, capabilities and App Check; enforce stable-ID receipts, revision preconditions and transactional write/change-log/receipt updates. Server receipt retention and cursor expiry/full-resync need an explicit policy.
3. Integrate the REST path with the existing session and role model on unsupported Firebase native targets. Real sign-in, token refresh, rules-authorized reads, phone/MFA and desktop App Check remain qualification tasks. Do not weaken production protections to make a probe pass.
4. Add a legacy-model adapter and migrate one feature at a time with exactly one writer. The REST probe exposes read-only raw Firestore document format; it is not the production patient repository or a replacement for existing workflows.
5. Preserve rejected/ambiguous operations for reconciliation. This prototype does not provide a production admin recovery interface, field-level clinical merge, attachment sync, automatic duplicate matching, partial-field rebasing, or signed/financial record semantics. An unresolved record holds its download page's cursor; a production implementation may use a durable remote shadow to avoid that head-of-line blocking.

The transport retries while the application is open and on resume. It cannot guarantee execution after a browser/app is closed. The simulated online switch is deliberate; it does not report the machine's actual connectivity.

## Asset provenance

- Uvilo mark: supplied Figma file `R0viGL5IhmGCMiTAf99Mxn`, node `30:2`, exported SVG. SHA-256: `32af02fde4c6fe8eef0d2103d97e98885e9e98bcd9c6f903bd57f9427244292c`.
- Inter variable font: Google Fonts `ofl/inter/Inter[opsz,wght].ttf`, local `InterVariable.ttf`, with `Inter-LICENSE.txt`. SHA-256: `29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031`.
- SQLite WASM: [Drift 2.35.3 release](https://github.com/simolus3/drift/releases/tag/drift-2.35.3), `sqlite3.wasm`. SHA-256: `efd308be92a34f3aa15f289a37f213b0230fd80888a1364326ee29579d892d37`.
- Worker: `drift-2.35.3/drift_worker.js` from the resolved pub package, copied to `web/drift_worker.dart.js`, with Drift's license. SHA-256: `a54b81412d4c4ab56653bb9e4c02912b0820bb37e2bba00722ddef4d78083d4a`.

Upgrade the Drift package, WASM and worker as a matched set, then rerun browser durability and multi-tab checks. Keep provider credentials and real records out of browser build output and review artifacts.

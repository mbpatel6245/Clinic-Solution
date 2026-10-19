# Public web homepage

The website root serves a lightweight, responsive marketing page without loading
Flutter or Firebase. The website uses full-page /login and /register links to start Flutter at the
selected screen. Existing hash links also load the application. Returning
through browser history to a public anchor reloads the public page cleanly.

Native app entry and routing are unchanged. Installed web-app shortcuts retain
login as their starting URL through web/manifest.json.

- web/index.html: public content, existing app loading element, metadata.
- web/marketing.css: responsive styles and reduced-motion support.
- web/marketing.js: app handoff without starting Firebase on the public page.
- web/flutter_bootstrap.js: existing Flutter startup, loaded only for app routes.

The page uses a plain headline, direct account actions, three workflow steps and
six concise feature cards. It makes no customer-count,
clinical-outcome or compliance claims. The page makes no claim that SMS/email
delivery is activated or free.

Browser verification requires Playwright and Chromium (or an installed Chrome
selected with CLINIC_BROWSER_CHANNEL=chrome). Run:

    node tool/marketing_page_test.cjs

The test checks the public page at five widths, feature layout, FAQ interactions, login and
registration handoff, browser Back and direct application links. It stubs the
Flutter bootstrap to test routing independently of authentication or network.
Run it against build/web by supplying that directory as the first argument.
A Flutter release build validates the generated web packaging.

The web router explicitly uses the selected hash/path at startup, because Flutter
is loaded after a public-page click. Native startup still uses /login; this is
covered by test/initial_location_test.dart. Public login and register links navigate to a fresh document so Flutter receives
the intended starting path.

After building, check the real application entry with:

    node tool/marketing_page_test.cjs build/web --real-app

This opens the existing Firebase-backed login screen, checks browser Back, and
opens registration without creating accounts or sending authentication messages.

The visual direction follows the simple structure of the user-provided reference
https://mydoc.fit/ while retaining original orByteza branding and product copy.
There is no doctor search, pricing/free-plan promise, AI capability, testimonial,
or customer statistic that the current product does not supply.

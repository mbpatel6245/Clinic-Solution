import {test} from "node:test";
import assert from "node:assert/strict";
import {deliveryDiagnostic} from "./delivery_diagnostics.js";
import {ProviderError} from "./notification_provider.js";
test("disabled clinic messaging is distinguished from Firebase verification", () => {
 const result = deliveryDiagnostic(new ProviderError("MSG91 notifications are not configured yet", false));
 assert.equal(result.code, "notifications_not_configured"); assert.match(result.message, /does not affect Firebase email verification/);
});
test("provider payloads and action tokens are never stored in diagnostics", () => {
 const result = deliveryDiagnostic(new ProviderError("bad token https://example.com/?oobCode=SECRET", false, 400));
 assert.equal(result.code, "provider_request_rejected"); assert.doesNotMatch(result.message, /SECRET|oobCode|https:/);
});
test("missing setup fields have actionable messages", () => {
 assert.equal(deliveryDiagnostic(new ProviderError("SMS template ID is not configured", false)).code, "configuration_missing");
 assert.equal(deliveryDiagnostic(new ProviderError("Missing template variable: patient_name", false)).code, "template_variable_missing");
});

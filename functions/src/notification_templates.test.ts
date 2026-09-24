import assert from "node:assert/strict";
import test from "node:test";
import {Timestamp} from "firebase-admin/firestore";
import {applyTemplate, appointmentEvent, defaultTemplate, renderText, templateCatalog, validateTemplate} from "./notification_templates.js";

test("every supported event has valid independent email and SMS defaults", () => {
  assert.equal(new Set(templateCatalog.map((item) => item.id)).size, templateCatalog.length);
  for (const item of templateCatalog) {
    for (const channel of ["email", "sms"] as const) {
      const template = defaultTemplate(item.id, channel);
      validateTemplate(template);
      const values = Object.fromEntries(item.variables.map((key) => [key, `sample-${key}`]));
      const result = applyTemplate({event: item.id, channel, recipient: "test@example.com", patientName: "Asha", clinicName: "Clinic", message: "Reminder", templateVariables: values}, template);
      assert.ok(result.message.length > 0);
      assert.equal(result.message.includes("{{"), false);
      if (channel === "email") assert.ok(result.subject);
    }
  }
});

test("owner edits change both the rendered body and provider message variables", () => {
  const template = {...defaultTemplate("account_created", "email"), subject: "Hello {{patient_name}}", body: "Welcome to {{clinic_name}}!", msg91_template_id: "msg-account", twilio_template_id: "sg-account"};
  const result = applyTemplate({channel: "email", recipient: "test@example.com", patientName: "Priya", clinicName: "Care", message: "old"}, template);
  assert.equal(result.subject, "Hello Priya");
  assert.equal(result.message, "Welcome to Care!");
  assert.equal(result.templateVariables?.message, result.message);
  assert.equal(result.templateVariables?.subject, result.subject);
  assert.deepEqual(result.providerTemplateIds, {msg91: "msg-account", twilio: "sg-account"});
});

test("missing reset link, disabled reset email and malformed variables fail closed", () => {
  const template = defaultTemplate("password_reset", "email");
  assert.throws(() => validateTemplate({...template, body: "No link"}));
  assert.throws(() => validateTemplate({...template, enabled: false}));
  assert.throws(() => validateTemplate({...template, body: "{{action_url}} {{password}}"}));
  assert.throws(() => validateTemplate({...template, body: "{{action_url}} {broken}"}));
  assert.throws(() => renderText(template.body, {patient_name: "Asha"}));
});

test("Unicode text is preserved and substitutions do not recursively expand user content", () => {
  assert.equal(renderText("नमस्ते {{patient_name}} — મુલાકાત", {patient_name: "પ્રીતિ"}), "नमस्ते પ્રીતિ — મુલાકાત");
  assert.equal(renderText("{{patient_name}}", {patient_name: "{{action_url}}", action_url: "secret"}), "{{action_url}}");
});

test("appointment events ignore irrelevant edits and select lifecycle changes", () => {
  const original = {status: "booked", scheduled_at: Timestamp.fromMillis(1000)};
  assert.equal(appointmentEvent(undefined, original), "appointment_booked");
  assert.equal(appointmentEvent(original, {...original, notes: "new note"}), undefined);
  assert.equal(appointmentEvent(original, {...original, scheduled_at: Timestamp.fromMillis(2000)}), "appointment_rescheduled");
  for (const status of ["confirmed", "cancelled", "completed"]) {
    assert.equal(appointmentEvent(original, {...original, status}), `appointment_${status}`);
  }
  assert.equal(appointmentEvent({...original, status: "cancelled"}, {...original, status: "cancelled", scheduled_at: Timestamp.fromMillis(2000)}), undefined);
});

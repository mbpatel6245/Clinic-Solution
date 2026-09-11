import assert from "node:assert/strict";
import test from "node:test";
import {normalizePhone} from "./notification_provider.js";
import {sendWithMsg91, type Msg91Config} from "./msg91.js";

const config: Msg91Config = {
  authKey: "test-key",
  defaultCountryCode: "91",
  smsTemplateId: "sms-template",
  whatsappTemplateName: "appointment_reminder",
  whatsappNamespace: "namespace",
  whatsappIntegratedNumber: "919900000000",
  emailTemplateId: "email-template",
  emailDomain: "example.com",
  emailFrom: "care@example.com",
  emailFromName: "Clinic",
};

test("normalizes an Indian local mobile number", () => {
  assert.equal(normalizePhone("98765 43210"), "919876543210");
});

test("builds the current MSG91 SMS Flow request without exposing credentials in the body", async () => {
  let requestBody = "";
  const fakeFetch: typeof fetch = async (_input, init) => {
    requestBody = String(init?.body);
    return new Response(JSON.stringify({request_id: "request-1"}), {status: 200});
  };
  const result = await sendWithMsg91(
    {
      channel: "sms",
      recipient: "9876543210",
      patientName: "Asha",
      clinicName: "City Clinic",
      message: "Appointment tomorrow",
    },
    config,
    fakeFetch,
  );
  const payload = JSON.parse(requestBody);
  assert.equal(payload.template_id, "sms-template");
  assert.equal(payload.recipients[0].mobiles, "919876543210");
  assert.equal(payload.recipients[0].message, "Appointment tomorrow");
  assert.equal(requestBody.includes("test-key"), false);
  assert.equal(result.messageId, "request-1");
});

test("rejects an invalid email before calling MSG91", async () => {
  let called = false;
  const fakeFetch: typeof fetch = async () => {
    called = true;
    return new Response("{}", {status: 200});
  };
  await assert.rejects(
    sendWithMsg91(
      {
        channel: "email",
        recipient: "not-an-email",
        patientName: "Patient",
        clinicName: "Clinic",
        message: "Reminder",
      },
      config,
      fakeFetch,
    ),
    /invalid/,
  );
  assert.equal(called, false);
});

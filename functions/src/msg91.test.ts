import assert from "node:assert/strict";
import test from "node:test";
import {normalizePhone, ProviderError} from "./notification_provider.js";
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

const syntheticJob = {channel: "sms" as const, recipient: "9876543210",
  patientName: "Integration Test", clinicName: "Demo clinic", message: "Synthetic integration test."};

test("captures the documented SMS Flow receipt in message", async () => {
  const result = await sendWithMsg91(syntheticJob, config, async () =>
    new Response(JSON.stringify({type: "success", message: "5e1e93cad6fc054d8e759a5b"})));
  assert.equal(result.messageId, "5e1e93cad6fc054d8e759a5b");
  assert.equal(result.acceptedStatus, "accepted");
});

test("email request uses the verified sender/template and captures data.unique_id", async () => {
  const result = await sendWithMsg91({...syntheticJob, channel: "email", recipient: "test@example.test"}, config,
    async (url, init) => {
      assert.equal(url, "https://control.msg91.com/api/v5/email/send");
      const payload = JSON.parse(String(init?.body));
      assert.deepEqual(payload.from, {name: "Clinic", email: "care@example.com"});
      assert.equal(payload.domain, "example.com");
      assert.equal(payload.template_id, "email-template");
      assert.equal(payload.recipients[0].to[0].email, "test@example.test");
      assert.equal(payload.recipients[0].variables.message, syntheticJob.message);
      return new Response(JSON.stringify({status: "success", hasError: false,
        data: {unique_id: "email-receipt"}, errors: {}, message: "Your request has been queued."}));
    });
  assert.equal(result.messageId, "email-receipt");
});

test("HTTP 200 application errors are rejected, not marked accepted", async () => {
  for (const body of [{type: "error", message: "private provider response"},
    {status: "error", hasError: true, data: {unique_id: "not-success"}}]) {
    await assert.rejects(sendWithMsg91(syntheticJob, config, async () => new Response(JSON.stringify(body))),
      (error: unknown) => error instanceof ProviderError && !error.retryable &&
        error.message === "MSG91 rejected the request");
  }
});

test("ambiguous success without a receipt is not automatically retried", async () => {
  await assert.rejects(sendWithMsg91(syntheticJob, config, async () => new Response("{}")),
    (error: unknown) => error instanceof ProviderError && !error.retryable && /status is unknown/.test(error.message));
});

test("missing credentials fail before fetch and remain non-retryable", async () => {
  await assert.rejects(sendWithMsg91(syntheticJob, {...config, authKey: ""},
    async () => {throw new Error("Must not make a network request");}),
  (error: unknown) => error instanceof ProviderError && !error.retryable && error.message === "MSG91_AUTH_KEY is not configured");
});

test("template variables cannot replace the authorized SMS recipient", async () => {
  await sendWithMsg91({...syntheticJob, templateVariables: {mobiles: "19999999999"}}, config,
    async (_url, init) => {
      assert.equal(JSON.parse(String(init?.body)).recipients[0].mobiles, "919876543210");
      return new Response('{"type":"success","message":"receipt"}');
    });
});

test("event SMS requires its event template instead of an unrelated global template", async () => {
  await assert.rejects(sendWithMsg91({...syntheticJob, event: "invoice_created"}, config,
    async () => {throw new Error("Must not send");}), /SMS template ID is not configured/);
});

test("HTTP errors retain retry classification without leaking provider bodies", async () => {
  for (const [status, retryable] of [[401, false], [429, true], [503, true]] as const) {
    await assert.rejects(sendWithMsg91(syntheticJob, config, async () =>
      new Response("private body with test-key", {status})),
    (error: unknown) => error instanceof ProviderError && error.retryable === retryable &&
      error.statusCode === status && !error.message.includes("test-key") && !error.message.includes("private"));
  }
});

test("IP allowlist rejection is actionable and never retried", async () => {
  for (const status of [200, 401]) {
    await assert.rejects(sendWithMsg91(syntheticJob, config, async () =>
      new Response(JSON.stringify({status: "fail", hasError: true, apiError: "418"}), {status})),
    (error: unknown) => error instanceof ProviderError && !error.retryable &&
      error.message === "MSG91 source IP is not whitelisted" && error.statusCode === 403);
  }
});

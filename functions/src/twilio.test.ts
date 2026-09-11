import assert from "node:assert/strict";
import test from "node:test";
import {createHmac} from "node:crypto";
import {
  sendWithTwilio,
  validateTwilioWebhook,
  type TwilioConfig,
} from "./twilio.js";

const config: TwilioConfig = {
  accountSid: "AC00000000000000000000000000000000",
  authToken: "secret-token",
  sendGridApiKey: "sendgrid-secret",
  defaultCountryCode: "91",
  messagingServiceSid: "MG00000000000000000000000000000000",
  smsFrom: "",
  smsContentSid: "",
  whatsappFrom: "14155238886",
  whatsappContentSid: "HX00000000000000000000000000000000",
  sendGridFromEmail: "care@example.com",
  sendGridFromName: "Clinic",
  sendGridTemplateId: "d-template",
  statusCallbackUrl: "https://example.com/twilioDeliveryWebhook",
};

test("builds a Twilio SMS request with E.164 recipient and callback", async () => {
  let requestBody = "";
  let authorization = "";
  const fakeFetch: typeof fetch = async (_input, init) => {
    requestBody = String(init?.body);
    authorization = new Headers(init?.headers).get("authorization") ?? "";
    return new Response(JSON.stringify({sid: "SM123", status: "queued"}), {
      status: 201,
      headers: {"content-type": "application/json"},
    });
  };
  const result = await sendWithTwilio(
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
  const form = new URLSearchParams(requestBody);
  assert.equal(form.get("To"), "+919876543210");
  assert.equal(form.get("MessagingServiceSid"), config.messagingServiceSid);
  assert.equal(form.get("Body"), "Appointment tomorrow");
  assert.equal(form.get("StatusCallback"), config.statusCallbackUrl);
  assert.match(authorization, /^Basic /);
  assert.equal(requestBody.includes("secret-token"), false);
  assert.equal(result.messageId, "SM123");
});

test("sends email through the current SendGrid v3 endpoint", async () => {
  let requestUrl = "";
  let requestBody = "";
  const fakeFetch: typeof fetch = async (input, init) => {
    requestUrl = String(input);
    requestBody = String(init?.body);
    return new Response(null, {status: 202, headers: {"x-message-id": "email-1"}});
  };
  const result = await sendWithTwilio(
    {
      channel: "email",
      recipient: "asha@example.com",
      patientName: "Asha",
      clinicName: "City Clinic",
      message: "Appointment tomorrow",
    },
    config,
    fakeFetch,
  );
  const payload = JSON.parse(requestBody);
  assert.equal(requestUrl, "https://api.sendgrid.com/v3/mail/send");
  assert.equal(payload.template_id, "d-template");
  assert.equal(payload.personalizations[0].dynamic_template_data.clinic_name, "City Clinic");
  assert.equal(result.messageId, "email-1");
});

test("validates Twilio form callback signatures", () => {
  const url = "https://example.com/twilioDeliveryWebhook";
  const params = {MessageSid: "SM123", MessageStatus: "delivered"};
  const source = `${url}MessageSidSM123MessageStatusdelivered`;
  const signature = createHmac("sha1", config.authToken)
    .update(source, "utf8")
    .digest("base64");
  assert.equal(
    validateTwilioWebhook(config.authToken, signature, url, params),
    true,
  );
  assert.equal(
    validateTwilioWebhook(config.authToken, signature, `${url}/wrong`, params),
    false,
  );
});

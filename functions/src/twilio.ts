import {
  ProviderError,
  normalizePhone,
  notificationVariables,
  required,
  validateEmail,
  type NotificationJob,
  type SendResult,
} from "./notification_provider.js";
import {createHmac, timingSafeEqual} from "node:crypto";

export interface TwilioConfig {
  accountSid: string;
  authToken: string;
  sendGridApiKey: string;
  defaultCountryCode: string;
  messagingServiceSid: string;
  smsFrom: string;
  smsContentSid: string;
  whatsappFrom: string;
  whatsappContentSid: string;
  sendGridFromEmail: string;
  sendGridFromName: string;
  sendGridTemplateId: string;
  statusCallbackUrl: string;
}

type FetchLike = typeof fetch;

export function validateTwilioWebhook(
  authToken: string,
  signature: string,
  url: string,
  params: Record<string, unknown>,
): boolean {
  let source = url;
  for (const key of Object.keys(params).sort()) {
    const value = params[key];
    const values = Array.isArray(value)
      ? value.map(String).sort()
      : [String(value ?? "")];
    for (const item of values) source += `${key}${item}`;
  }
  const expected = createHmac("sha1", authToken)
    .update(source, "utf8")
    .digest("base64");
  const suppliedBuffer = Buffer.from(signature);
  const expectedBuffer = Buffer.from(expected);
  return suppliedBuffer.length === expectedBuffer.length &&
    timingSafeEqual(suppliedBuffer, expectedBuffer);
}

function retryable(status: number): boolean {
  return status === 408 || status === 429 || status >= 500;
}

async function responseError(response: Response): Promise<ProviderError> {
  const text = await response.text();
  let message = text;
  try {
    const body = JSON.parse(text) as {message?: unknown; errors?: unknown};
    message = typeof body.message === "string" ? body.message : JSON.stringify(body.errors ?? body);
  } catch {
    // Keep the plain-text provider response.
  }
  return new ProviderError(message.slice(0, 500) || "Twilio rejected the request", retryable(response.status), response.status);
}

function e164(value: string, countryCode: string): string {
  return `+${normalizePhone(value, countryCode)}`;
}

async function sendMessage(
  job: NotificationJob,
  config: TwilioConfig,
  fetcher: FetchLike,
): Promise<SendResult> {
  const accountSid = required(config.accountSid, "TWILIO_ACCOUNT_SID");
  const form = new URLSearchParams();
  form.set("To", job.channel === "whatsapp" ? `whatsapp:${e164(job.recipient, config.defaultCountryCode)}` : e164(job.recipient, config.defaultCountryCode));

  if (job.channel === "whatsapp") {
    form.set("From", `whatsapp:${e164(required(config.whatsappFrom, "Twilio WhatsApp sender"), config.defaultCountryCode)}`);
    form.set("ContentSid", required(job.templateId || config.whatsappContentSid, "Twilio WhatsApp Content SID"));
    form.set("ContentVariables", JSON.stringify({"1": job.patientName, "2": job.clinicName, "3": job.message}));
  } else {
    if (config.messagingServiceSid.trim()) {
      form.set("MessagingServiceSid", config.messagingServiceSid.trim());
    } else {
      form.set("From", required(config.smsFrom, "Twilio SMS sender"));
    }
    const contentSid = job.templateId || (job.event ? "" : config.smsContentSid);
    if (contentSid.trim()) {
      form.set("ContentSid", contentSid.trim());
      form.set("ContentVariables", JSON.stringify({"1": job.patientName, "2": job.clinicName, "3": job.message}));
    } else {
      form.set("Body", job.message);
    }
  }
  if (config.statusCallbackUrl.trim()) form.set("StatusCallback", config.statusCallbackUrl.trim());

  let response: Response;
  try {
    response = await fetcher(
      `https://api.twilio.com/2010-04-01/Accounts/${encodeURIComponent(accountSid)}/Messages.json`,
      {
        method: "POST",
        headers: {
          authorization: `Basic ${Buffer.from(`${accountSid}:${required(config.authToken, "TWILIO_AUTH_TOKEN")}`).toString("base64")}`,
          "content-type": "application/x-www-form-urlencoded",
        },
        body: form,
        signal: AbortSignal.timeout(20_000),
      },
    );
  } catch (error) {
    throw new ProviderError(`Twilio request failed: ${error instanceof Error ? error.message : "network error"}`, true);
  }
  if (!response.ok) throw await responseError(response);
  const body = (await response.json()) as {sid?: unknown; status?: unknown};
  return {
    provider: "twilio",
    messageId: typeof body.sid === "string" ? body.sid : "",
    acceptedStatus: typeof body.status === "string" ? body.status : "accepted",
  };
}

async function sendEmail(
  job: NotificationJob,
  config: TwilioConfig,
  fetcher: FetchLike,
): Promise<SendResult> {
  const templateId = job.templateId || (job.event ? "" : required(config.sendGridTemplateId, "SendGrid template ID"));
  let response: Response;
  try {
    response = await fetcher("https://api.sendgrid.com/v3/mail/send", {
      method: "POST",
      headers: {
        authorization: `Bearer ${required(config.sendGridApiKey, "SENDGRID_API_KEY")}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        personalizations: [{
          to: [{email: validateEmail(job.recipient), name: job.patientName}],
          ...(templateId ? {dynamic_template_data: notificationVariables(job)} : {}),
        }],
        from: {
          email: required(config.sendGridFromEmail, "SendGrid sender email"),
          name: required(config.sendGridFromName, "SendGrid sender name"),
        },
        ...(templateId ? {template_id: templateId} : {
          subject: required(job.subject ?? "", "Email subject"),
          content: [{type: "text/plain", value: job.message}],
        }),
      }),
      signal: AbortSignal.timeout(20_000),
    });
  } catch (error) {
    throw new ProviderError(`SendGrid request failed: ${error instanceof Error ? error.message : "network error"}`, true);
  }
  if (!response.ok) throw await responseError(response);
  return {
    provider: "twilio",
    messageId: response.headers.get("x-message-id") ?? "",
    acceptedStatus: "accepted",
  };
}

export async function sendWithTwilio(
  job: NotificationJob,
  config: TwilioConfig,
  fetcher: FetchLike = fetch,
): Promise<SendResult> {
  return job.channel === "email"
    ? sendEmail(job, config, fetcher)
    : sendMessage(job, config, fetcher);
}

import {
  ProviderError,
  normalizePhone,
  notificationVariables,
  required,
  validateEmail,
  type NotificationJob,
  type SendResult,
} from "./notification_provider.js";

export interface Msg91Config {
  authKey: string;
  defaultCountryCode: string;
  smsTemplateId: string;
  whatsappTemplateName: string;
  whatsappNamespace: string;
  whatsappIntegratedNumber: string;
  emailTemplateId: string;
  emailDomain: string;
  emailFrom: string;
  emailFromName: string;
}

type FetchLike = typeof fetch;

const SMS_URL = "https://control.msg91.com/api/v5/flow";
const EMAIL_URL = "https://control.msg91.com/api/v5/email/send";
const WHATSAPP_URL =
  "https://control.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/";

function findMessageId(body: unknown): string {
  if (!body || typeof body !== "object") return "";
  const record = body as Record<string, unknown>;
  for (const key of ["request_id", "message_id", "unique_id", "id"]) {
    if (typeof record[key] === "string" && record[key].trim()) return record[key].trim();
  }
  // SMS Flow returns its receipt in `message`; email uses data.unique_id.
  // Never interpret an error description or an email's prose as a receipt.
  if (record.type === "success" && typeof record.message === "string") return record.message.trim();
  const nested = record.data;
  return nested && typeof nested === "object" ? findMessageId(nested) : "";
}

async function post(
  url: string,
  payload: Record<string, unknown>,
  config: Msg91Config,
  fetcher: FetchLike,
): Promise<SendResult> {
  const authKey = required(config.authKey, "MSG91_AUTH_KEY");
  let response: Response;
  try {
    response = await fetcher(url, {
      method: "POST",
      headers: {
        accept: "application/json",
        authkey: authKey,
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(20_000),
    });
  } catch {
    throw new ProviderError(
      "MSG91 request failed; check provider logs before a manual resend",
      true,
    );
  }

  const text = await response.text();
  let body: unknown = text;
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    // Keep the provider's plain-text response.
  }
  const record = body && typeof body === "object" ? body as Record<string, unknown> : {};
  if (String(record.apiError) === "418" || String(record.code) === "418") {
    throw new ProviderError("MSG91 source IP is not whitelisted", false, 403);
  }
  if (!response.ok) {
    throw new ProviderError(
      `MSG91 rejected the request (HTTP ${response.status})`,
      response.status === 408 || response.status === 429 || response.status >= 500,
      response.status,
    );
  }
  if (record.hasError === true || ["error", "failed", "failure"].includes(String(record.type).toLowerCase()) ||
      ["error", "failed", "failure"].includes(String(record.status).toLowerCase())) {
    // MSG91 can return application-level errors with HTTP 200.
    throw new ProviderError("MSG91 rejected the request", false, 400);
  }
  const messageId = findMessageId(body);
  if (!messageId) {
    // Do not claim success or blindly resend an ambiguous accepted request.
    throw new ProviderError("MSG91 delivery status is unknown; check provider logs before resending", false);
  }
  return {
    provider: "msg91",
    messageId,
    acceptedStatus: "accepted",
  };
}

export async function sendWithMsg91(
  job: NotificationJob,
  config: Msg91Config,
  fetcher: FetchLike = fetch,
): Promise<SendResult> {
  const vars = notificationVariables(job);
  if (job.channel === "sms") {
    return post(
      SMS_URL,
      {
        template_id: required(job.templateId || (job.event ? "" : config.smsTemplateId), "SMS template ID"),
        short_url: "0",
        recipients: [
          {
            ...vars,
            mobiles: normalizePhone(job.recipient, config.defaultCountryCode),
          },
        ],
      },
      config,
      fetcher,
    );
  }

  if (job.channel === "email") {
    return post(
      EMAIL_URL,
      {
        recipients: [
          {
            to: [{name: job.patientName, email: validateEmail(job.recipient)}],
            variables: vars,
          },
        ],
        from: {
          name: required(config.emailFromName, "Email sender name"),
          email: required(config.emailFrom, "Email sender address"),
        },
        domain: required(config.emailDomain, "Email domain"),
        template_id: required(job.templateId || config.emailTemplateId, "Email template ID"),
      },
      config,
      fetcher,
    );
  }

  const componentValues = [job.patientName, job.clinicName, job.message];
  const components = Object.fromEntries(
    componentValues.map((value, index) => [
      `body_${index + 1}`,
      {type: "text", value},
    ]),
  );
  return post(
    WHATSAPP_URL,
    {
      integrated_number: required(
        config.whatsappIntegratedNumber,
        "WhatsApp integrated number",
      ),
      content_type: "template",
      payload: {
        messaging_product: "whatsapp",
        type: "template",
        template: {
          name: required(
            job.templateId || config.whatsappTemplateName,
            "WhatsApp template name",
          ),
          language: {
            code: job.templateLanguage || "en",
            policy: "deterministic",
          },
          namespace: required(config.whatsappNamespace, "WhatsApp namespace"),
          to_and_components: [
            {
              to: [normalizePhone(job.recipient, config.defaultCountryCode)],
              components,
            },
          ],
        },
      },
    },
    config,
    fetcher,
  );
}

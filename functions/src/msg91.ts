export type NotificationChannel = "email" | "sms" | "whatsapp";

export interface NotificationJob {
  channel: NotificationChannel;
  recipient: string;
  patientName: string;
  clinicName: string;
  message: string;
  templateId?: string;
  templateLanguage?: string;
  templateVariables?: Record<string, string>;
}

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

export interface SendResult {
  provider: "msg91";
  messageId: string;
  acceptedStatus: string;
}

export class ProviderError extends Error {
  constructor(
    message: string,
    readonly retryable: boolean,
    readonly statusCode?: number,
  ) {
    super(message);
    this.name = "ProviderError";
  }
}

type FetchLike = typeof fetch;

const SMS_URL = "https://control.msg91.com/api/v5/flow";
const EMAIL_URL = "https://control.msg91.com/api/v5/email/send";
const WHATSAPP_URL =
  "https://control.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/";

function required(value: string, name: string): string {
  const cleaned = value.trim();
  if (!cleaned) throw new ProviderError(`${name} is not configured`, false);
  return cleaned;
}

export function normalizePhone(value: string, countryCode = "91"): string {
  const digits = value.replace(/\D/g, "");
  if (digits.length === 10) return `${countryCode.replace(/\D/g, "")}${digits}`;
  if (digits.length < 11 || digits.length > 15) {
    throw new ProviderError("Recipient phone number must include a valid country code", false);
  }
  return digits;
}

function validateEmail(value: string): string {
  const email = value.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new ProviderError("Recipient email address is invalid", false);
  }
  return email;
}

function responseMessage(body: unknown): string {
  if (typeof body === "string") return body.slice(0, 500);
  if (body && typeof body === "object") {
    const record = body as Record<string, unknown>;
    const value = record.message ?? record.error ?? record.type;
    if (typeof value === "string") return value.slice(0, 500);
  }
  return "MSG91 rejected the request";
}

function findMessageId(body: unknown): string {
  if (!body || typeof body !== "object") return "";
  const record = body as Record<string, unknown>;
  for (const key of ["request_id", "message_id", "id"]) {
    if (typeof record[key] === "string") return record[key] as string;
  }
  const nested = record.data;
  return nested && typeof nested === "object" ? findMessageId(nested) : "";
}

function variables(job: NotificationJob): Record<string, string> {
  return {
    patient_name: job.patientName,
    clinic_name: job.clinicName,
    message: job.message,
    ...job.templateVariables,
  };
}

async function post(
  url: string,
  payload: Record<string, unknown>,
  config: Msg91Config,
  fetcher: FetchLike,
): Promise<SendResult> {
  let response: Response;
  try {
    response = await fetcher(url, {
      method: "POST",
      headers: {
        accept: "application/json",
        authkey: required(config.authKey, "MSG91_AUTH_KEY"),
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(20_000),
    });
  } catch (error) {
    throw new ProviderError(
      `MSG91 request failed: ${error instanceof Error ? error.message : "network error"}`,
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
  if (!response.ok) {
    throw new ProviderError(
      responseMessage(body),
      response.status === 408 || response.status === 429 || response.status >= 500,
      response.status,
    );
  }
  return {
    provider: "msg91",
    messageId: findMessageId(body),
    acceptedStatus: "accepted",
  };
}

export async function sendWithMsg91(
  job: NotificationJob,
  config: Msg91Config,
  fetcher: FetchLike = fetch,
): Promise<SendResult> {
  const vars = variables(job);
  if (job.channel === "sms") {
    return post(
      SMS_URL,
      {
        template_id: required(job.templateId || config.smsTemplateId, "SMS template ID"),
        short_url: "0",
        recipients: [
          {
            mobiles: normalizePhone(job.recipient, config.defaultCountryCode),
            ...vars,
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

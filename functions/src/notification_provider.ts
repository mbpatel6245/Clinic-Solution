export type NotificationChannel = "email" | "sms" | "whatsapp";
export type NotificationProviderName = "msg91" | "twilio";

export interface NotificationJob {
  channel: NotificationChannel;
  recipient: string;
  patientName: string;
  clinicName: string;
  message: string;
  subject?: string;
  event?: string;
  providerTemplateIds?: Partial<Record<NotificationProviderName, string>>;
  templateId?: string;
  templateLanguage?: string;
  templateVariables?: Record<string, string>;
}

export interface SendResult {
  provider: NotificationProviderName;
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

export function required(value: string, name: string): string {
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

export function validateEmail(value: string): string {
  const email = value.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new ProviderError("Recipient email address is invalid", false);
  }
  return email;
}

export function notificationVariables(job: NotificationJob): Record<string, string> {
  return {
    patient_name: job.patientName,
    clinic_name: job.clinicName,
    message: job.message,
    ...job.templateVariables,
  };
}

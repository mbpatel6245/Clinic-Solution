import catalogData from "./template_catalog.json";
import {ProviderError, type NotificationJob} from "./notification_provider.js";

export type TemplateChannel = "email" | "sms";
export interface TemplateDefinition {
  id: string; label: string; category: string; variables: string[]; required: string[];
  email: {subject: string; body: string}; sms: {body: string};
}
export interface MessageTemplate {
  event: string; channel: TemplateChannel; locale: string; enabled: boolean;
  subject: string; body: string; msg91_template_id: string; twilio_template_id: string;
}
export const templateCatalog = catalogData as TemplateDefinition[];
export function definition(event: string): TemplateDefinition {
  const result = templateCatalog.find((item) => item.id === event);
  if (!result) throw new ProviderError("Unknown notification event", false);
  return result;
}
export function defaultTemplate(event: string, channel: TemplateChannel): MessageTemplate {
  const item = definition(event);
  return {event, channel, locale: "en", enabled: true,
    subject: channel === "email" ? item.email.subject : "", body: item[channel].body,
    msg91_template_id: "", twilio_template_id: ""};
}
export function validateTemplate(template: MessageTemplate): void {
  const item = definition(template.event);
  if (!["email", "sms"].includes(template.channel) || !["en", "hi", "gu"].includes(template.locale)) {
    throw new ProviderError("Invalid template channel or language", false);
  }
  if (typeof template.enabled !== "boolean" || typeof template.body !== "string" ||
      !template.body.trim() || template.body.length > (template.channel === "sms" ? 1600 : 10000) ||
      typeof template.subject !== "string" || template.subject.length > 200 || /[\r\n]/.test(template.subject) ||
      (template.channel === "email" && !template.subject.trim())) {
    throw new ProviderError("Template subject or message is invalid", false);
  }
  const content = `${template.subject}\n${template.body}`;
  const variables = [...content.matchAll(/\{\{\s*([a-z_]+)\s*\}\}/g)].map((m) => m[1]);
  if (variables.some((name) => !item.variables.includes(name)) || /[{}]/.test(content.replace(/\{\{\s*[a-z_]+\s*\}\}/g, ""))) {
    throw new ProviderError("Template contains unknown or malformed placeholders", false);
  }
  if (item.required.some((name) => ![...template.body.matchAll(/\{\{\s*([a-z_]+)\s*\}\}/g)].some((m) => m[1] === name))) {
    throw new ProviderError("Template is missing a required message placeholder", false);
  }
  if (template.event === "password_reset" && template.channel === "email" && !template.enabled) {
    throw new ProviderError("Password reset email must remain enabled", false);
  }
}
export function renderText(text: string, variables: Record<string, string>): string {
  return text.replace(/\{\{\s*([a-z_]+)\s*\}\}/g, (_, key: string) => {
    if (typeof variables[key] !== "string" || !variables[key].trim()) {
      throw new ProviderError(`Missing template variable: ${key}`, false);
    }
    return variables[key];
  });
}
export function applyTemplate(job: NotificationJob, template: MessageTemplate): NotificationJob {
  validateTemplate(template);
  const variables = {patient_name: job.patientName, clinic_name: job.clinicName, message: job.message, ...job.templateVariables};
  const subject = renderText(template.subject, variables).replace(/[\r\n]+/g, " ");
  const message = renderText(template.body, variables);
  return {...job, message, subject,
    providerTemplateIds: {msg91: template.msg91_template_id, twilio: template.twilio_template_id},
    templateVariables: {...variables, message, subject},
  };
}

export function appointmentEvent(before: Record<string, unknown> | undefined, after: Record<string, unknown>): string | undefined {
  if (!before) return after.status === "cancelled" ? undefined : after.status === "confirmed" ? "appointment_confirmed" : "appointment_booked";
  if (before.status !== after.status) {
    const events: Record<string, string> = {cancelled: "appointment_cancelled", confirmed: "appointment_confirmed", completed: "appointment_completed", booked: "appointment_booked"};
    if (events[String(after.status)]) return events[String(after.status)];
  }
  const millis = (value: unknown) => (value as {toMillis?: () => number})?.toMillis?.();
  if (!["cancelled", "completed"].includes(String(after.status)) && millis(before.scheduled_at) !== millis(after.scheduled_at)) return "appointment_rescheduled";
  return undefined;
}

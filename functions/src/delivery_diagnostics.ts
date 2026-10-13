import {ProviderError} from "./notification_provider.js";

/** Store only classified, actionable errors, never provider response bodies or action links. */
export function deliveryDiagnostic(error: unknown): {code: string; message: string} {
  if (!(error instanceof ProviderError)) return {code: "delivery_unavailable", message: "Notification service unavailable. Delivery will be retried when possible."};
  if (error.message === "MSG91 notifications are not configured yet") return {code: "notifications_not_configured", message: "Clinic notifications are disabled. Configure MSG91 credentials, verified email sender and approved SMS templates, then enable notifications. This does not affect Firebase email verification."};
  const missing = /^([A-Za-z0-9 _-]{1,80}) is not configured$/.exec(error.message);
  if (missing) return {code: "configuration_missing", message: `Configure ${missing[1]} in notification settings before sending.`};
  const variable = /^Missing template variable: ([a-z_]+)$/.exec(error.message);
  if (variable) return {code: "template_variable_missing", message: `The notification template requires ${variable[1]}. Check its event and variables.`};
  if (error.statusCode === 401 || error.statusCode === 403) return {code: "provider_authorization_failed", message: "Messaging provider rejected authorization. Check the active auth key and sender/domain approval."};
  if (error.statusCode === 400 || error.statusCode === 422) return {code: "provider_request_rejected", message: "Messaging provider rejected the request. Check recipient, approved template ID and required variables."};
  if (error.retryable) return {code: "provider_temporarily_unavailable", message: "Messaging provider is temporarily unavailable or rate limited. Delivery will be retried when possible."};
  return {code: "provider_delivery_rejected", message: "Messaging provider rejected delivery. Check sender approval, recipient and provider template settings."};
}

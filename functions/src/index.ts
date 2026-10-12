import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {
  FieldValue,
  Timestamp,
  getFirestore,
  type DocumentReference,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {defineSecret, defineString, type SecretParam} from "firebase-functions/params";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {
  sendWithMsg91,
  type Msg91Config,
} from "./msg91.js";
import {
  ProviderError,
  type NotificationChannel,
  type NotificationJob,
  type NotificationProviderName,
  type SendResult,
} from "./notification_provider.js";
import {
  sendWithTwilio,
  validateTwilioWebhook,
  type TwilioConfig,
} from "./twilio.js";
import {randomBytes, timingSafeEqual} from "node:crypto";
import {applyTemplate, defaultTemplate, type MessageTemplate} from "./notification_templates.js";
import {createNotificationHandlers} from "./event_notifications.js";

initializeApp();
const db = getFirestore();

// Enable only after MSG91 sender, templates and credentials are configured.
const notificationsEnabled = process.env.CLINIC_NOTIFICATIONS_ENABLED === "true";
const MSG91_AUTH_KEY = notificationsEnabled ? defineSecret("MSG91_AUTH_KEY") : undefined;
const NOTIFICATION_WEBHOOK_SECRET = notificationsEnabled ? defineSecret("NOTIFICATION_WEBHOOK_SECRET") : undefined;
// Optional legacy adapters are retained, but are not bound or selected in this deployment.
const TWILIO_ACCOUNT_SID: SecretParam | undefined = undefined;
const TWILIO_AUTH_TOKEN: SecretParam | undefined = undefined;
const SENDGRID_API_KEY: SecretParam | undefined = undefined;
function configuredSecrets(...values: (SecretParam | undefined)[]): SecretParam[] {
  return values.filter((value): value is SecretParam => value !== undefined);
}
function credential(value: SecretParam | undefined): string { return value?.value() ?? ""; }
const DEFAULT_COUNTRY_CODE = defineString("MSG91_DEFAULT_COUNTRY_CODE", {default: "91"});
const SMS_TEMPLATE_ID = defineString("MSG91_SMS_TEMPLATE_ID", {default: ""});
const WHATSAPP_TEMPLATE_NAME = defineString("MSG91_WHATSAPP_TEMPLATE_NAME", {default: ""});
const WHATSAPP_NAMESPACE = defineString("MSG91_WHATSAPP_NAMESPACE", {default: ""});
const WHATSAPP_NUMBER = defineString("MSG91_WHATSAPP_INTEGRATED_NUMBER", {default: ""});
const EMAIL_TEMPLATE_ID = defineString("MSG91_EMAIL_TEMPLATE_ID", {default: ""});
const EMAIL_DOMAIN = defineString("MSG91_EMAIL_DOMAIN", {default: ""});
const EMAIL_FROM = defineString("MSG91_EMAIL_FROM", {default: ""});
const EMAIL_FROM_NAME = defineString("MSG91_EMAIL_FROM_NAME", {default: "Clinic"});
const TWILIO_MESSAGING_SERVICE_SID = defineString("TWILIO_MESSAGING_SERVICE_SID", {default: ""});
const TWILIO_SMS_FROM = defineString("TWILIO_SMS_FROM", {default: ""});
const TWILIO_SMS_CONTENT_SID = defineString("TWILIO_SMS_CONTENT_SID", {default: ""});
const TWILIO_WHATSAPP_FROM = defineString("TWILIO_WHATSAPP_FROM", {default: ""});
const TWILIO_WHATSAPP_CONTENT_SID = defineString("TWILIO_WHATSAPP_CONTENT_SID", {default: ""});
const SENDGRID_FROM_EMAIL = defineString("SENDGRID_FROM_EMAIL", {default: ""});
const SENDGRID_FROM_NAME = defineString("SENDGRID_FROM_NAME", {default: "Clinic"});
const SENDGRID_TEMPLATE_ID = defineString("SENDGRID_TEMPLATE_ID", {default: ""});
const TWILIO_STATUS_CALLBACK_URL = defineString("TWILIO_STATUS_CALLBACK_URL", {default: ""});
const CLINIC_APP_URL = defineString("CLINIC_APP_URL", {default: "https://clinic.orbyteza.com"});

const MAX_ATTEMPTS = 3;
const REGION = "asia-south1";

export const {
  dispatchEventNotifications, notifyAccountCreated, notifyAccountApproved,
  notifyMemberApproved, notifyAppointmentChanged, notifyInvoiceChanged,
} = createNotificationHandlers(
  async (job) => sendNotification(job, await providerSelection()),
  configuredSecrets(MSG91_AUTH_KEY),
);

interface ProviderSelection {
  primary: NotificationProviderName;
  fallback: NotificationProviderName;
  fallbackEnabled: boolean;
  defaultCountryCode: string;
  msg91: Record<string, string>;
  twilio: Record<string, string>;
}

function stringMap(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object") return {};
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>).map(([key, item]) => [key, asString(item)]),
  );
}

function providerName(value: unknown, fallback: NotificationProviderName): NotificationProviderName {
  return value === "twilio" || value === "msg91" ? value : fallback;
}

async function providerSelection(): Promise<ProviderSelection> {
  const snapshot = await db.doc("platform_settings/notifications").get();
  const data = snapshot.data() ?? {};
  return {
    primary: "msg91",
    fallback: providerName(data.fallback_provider, "twilio"),
    fallbackEnabled: false,
    defaultCountryCode: asString(data.default_country_code, DEFAULT_COUNTRY_CODE.value()),
    msg91: stringMap(data.msg91),
    twilio: stringMap(data.twilio),
  };
}

function msg91Config(settings: ProviderSelection): Msg91Config {
  const values = settings.msg91;
  return {
    authKey: credential(MSG91_AUTH_KEY),
    defaultCountryCode: settings.defaultCountryCode,
    smsTemplateId: values.sms_template_id || SMS_TEMPLATE_ID.value(),
    whatsappTemplateName: values.whatsapp_template_name || WHATSAPP_TEMPLATE_NAME.value(),
    whatsappNamespace: values.whatsapp_namespace || WHATSAPP_NAMESPACE.value(),
    whatsappIntegratedNumber: values.whatsapp_integrated_number || WHATSAPP_NUMBER.value(),
    emailTemplateId: values.email_template_id || EMAIL_TEMPLATE_ID.value(),
    emailDomain: values.email_domain || EMAIL_DOMAIN.value(),
    emailFrom: values.email_from || EMAIL_FROM.value(),
    emailFromName: values.email_from_name || EMAIL_FROM_NAME.value(),
  };
}

function twilioConfig(settings: ProviderSelection): TwilioConfig {
  const values = settings.twilio;
  return {
    accountSid: credential(TWILIO_ACCOUNT_SID),
    authToken: credential(TWILIO_AUTH_TOKEN),
    sendGridApiKey: credential(SENDGRID_API_KEY),
    defaultCountryCode: settings.defaultCountryCode,
    messagingServiceSid: values.messaging_service_sid || TWILIO_MESSAGING_SERVICE_SID.value(),
    smsFrom: values.sms_from || TWILIO_SMS_FROM.value(),
    smsContentSid: values.sms_content_sid || TWILIO_SMS_CONTENT_SID.value(),
    whatsappFrom: values.whatsapp_from || TWILIO_WHATSAPP_FROM.value(),
    whatsappContentSid: values.whatsapp_content_sid || TWILIO_WHATSAPP_CONTENT_SID.value(),
    sendGridFromEmail: values.sendgrid_from_email || SENDGRID_FROM_EMAIL.value(),
    sendGridFromName: values.sendgrid_from_name || SENDGRID_FROM_NAME.value(),
    sendGridTemplateId: values.sendgrid_template_id || SENDGRID_TEMPLATE_ID.value(),
    statusCallbackUrl: values.status_callback_url || TWILIO_STATUS_CALLBACK_URL.value(),
  };
}

async function sendThroughProvider(
  provider: NotificationProviderName,
  job: NotificationJob,
  settings: ProviderSelection,
): Promise<SendResult> {
  if (job.providerTemplateIds) {
    job = {...job, templateId: job.providerTemplateIds[provider] || job.templateId || undefined};
  }
  return provider === "twilio"
    ? sendWithTwilio(job, twilioConfig(settings))
    : sendWithMsg91(job, msg91Config(settings));
}

async function sendNotification(
  job: NotificationJob,
  settings: ProviderSelection,
  providerOverride?: NotificationProviderName,
): Promise<SendResult> {
  if (!notificationsEnabled) throw new ProviderError("MSG91 notifications are not configured yet", false);
  if (providerOverride && providerOverride !== "msg91") throw new ProviderError("Only MSG91 is enabled", false);
  if (job.event && job.channel !== "whatsapp") {
    const locale = ["hi", "gu"].includes(job.templateLanguage ?? "") ? job.templateLanguage! : "en";
    let snapshot = await db.doc(`notification_templates/${job.event}_${job.channel}_${locale}`).get();
    if (!snapshot.exists && locale !== "en") snapshot = await db.doc(`notification_templates/${job.event}_${job.channel}_en`).get();
    const template = snapshot.exists ? snapshot.data() as unknown as MessageTemplate : defaultTemplate(job.event, job.channel);
    if (template.enabled === false) return {provider: settings.primary, messageId: "", acceptedStatus: "disabled"};
    job = applyTemplate(job, template);
  }
  const providers = providerOverride
    ? [providerOverride]
    : [
        settings.primary,
        ...(settings.fallbackEnabled && settings.fallback !== settings.primary
          ? [settings.fallback]
          : []),
      ];
  let lastError: unknown;
  for (const provider of providers) {
    try {
      const providerJob = !providerOverride && provider !== settings.primary
        ? {...job, templateId: undefined}
        : job;
      return await sendThroughProvider(provider, providerJob, settings);
    } catch (error) {
      lastError = error;
      logger.warn("Notification provider attempt failed", {
        provider,
        retryable: error instanceof ProviderError ? error.retryable : true,
      });
    }
  }
  throw lastError ?? new ProviderError("No notification provider is configured", false);
}

function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value.trim() : fallback;
}

function channel(value: unknown): NotificationChannel {
  if (value === "email" || value === "sms" || value === "whatsapp") return value;
  throw new ProviderError("Unsupported notification channel", false);
}

function jobFromData(data: Record<string, unknown>, clinicName: string): NotificationJob {
  const rawVariables = data.template_variables;
  const templateVariables =
    rawVariables && typeof rawVariables === "object"
      ? Object.fromEntries(
          Object.entries(rawVariables as Record<string, unknown>).map(([key, value]) => [
            key,
            String(value),
          ]),
        )
      : undefined;
  return {
    channel: channel(data.channel),
    recipient: asString(data.recipient),
    patientName: asString(data.patient_name, "Patient"),
    clinicName,
    message: asString(data.message),
    event: data.channel === "whatsapp" ? undefined : ({appointment: "appointment_reminder", vaccination: "vaccination_reminder", follow_up: "follow_up_reminder", followup: "follow_up_reminder"}[asString(data.type).toLowerCase()] ?? "general_reminder"),
    templateId: asString(data.template_id) || undefined,
    templateLanguage: asString(data.template_language) || undefined,
    templateVariables,
  };
}

async function claim(
  ref: DocumentReference,
  expectedStatus: "scheduled" | "retry" | "processing",
): Promise<{job: NotificationJob; attempts: number} | null> {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() as Record<string, unknown> | undefined;
    if (!data || data.status !== expectedStatus || data.consent !== true) return null;
    const attempts = Number(data.attempts ?? 0);
    if (attempts >= MAX_ATTEMPTS) {
      transaction.update(ref, {status: "failed", failure_reason: "Maximum retries reached"});
      return null;
    }
    const clinicRef = ref.parent.parent;
    if (!clinicRef) return null;
    const clinic = await transaction.get(clinicRef);
    const clinicName = asString(clinic.data()?.name, "Clinic");
    transaction.update(ref, {
      status: "processing",
      attempts: attempts + 1,
      provider: FieldValue.delete(),
      processing_started_at: FieldValue.serverTimestamp(),
      lease_expires_at: Timestamp.fromMillis(Date.now() + 5 * 60_000),
      updated_at: FieldValue.serverTimestamp(),
    });
    return {job: jobFromData(data, clinicName), attempts: attempts + 1};
  });
}

async function deliver(
  ref: DocumentReference,
  expectedStatus: "scheduled" | "retry" | "processing",
  settings: ProviderSelection,
): Promise<void> {
  const claimed = await claim(ref, expectedStatus);
  if (!claimed) return;
  try {
    const result = await sendNotification(claimed.job, settings);
    await ref.update({
      status: result.acceptedStatus === "disabled" ? "skipped" : "sent",
      provider: result.provider,
      provider_message_id: result.messageId,
      provider_status: result.acceptedStatus,
      sent_at: FieldValue.serverTimestamp(),
      lease_expires_at: FieldValue.delete(),
      failure_reason: FieldValue.delete(),
      updated_at: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    const providerError =
      error instanceof ProviderError
        ? error
        : new ProviderError(error instanceof Error ? error.message : "Unknown delivery error", true);
    const shouldRetry = providerError.retryable && claimed.attempts < MAX_ATTEMPTS;
    const retryMinutes = 2 ** claimed.attempts;
    await ref.update({
      status: shouldRetry ? "retry" : "failed",
      failure_reason: providerError.message.slice(0, 500),
      next_attempt_at: shouldRetry
        ? Timestamp.fromMillis(Date.now() + retryMinutes * 60_000)
        : FieldValue.delete(),
      lease_expires_at: FieldValue.delete(),
      updated_at: FieldValue.serverTimestamp(),
    });
    logger.error("Notification delivery failed", {
      reminderPath: ref.path,
      retryable: shouldRetry,
      statusCode: providerError.statusCode,
    });
  }
}

async function dueDocuments(): Promise<
  Array<{ref: DocumentReference; status: "scheduled" | "retry" | "processing"}>
> {
  const now = Timestamp.now();
  const [scheduled, retries, expired] = await Promise.all([
    db.collectionGroup("reminders")
      .where("status", "==", "scheduled")
      .where("consent", "==", true)
      .where("scheduled_at", "<=", now)
      .limit(100)
      .get(),
    db.collectionGroup("reminders")
      .where("status", "==", "retry")
      .where("consent", "==", true)
      .where("next_attempt_at", "<=", now)
      .limit(100)
      .get(),
    db.collectionGroup("reminders")
      .where("status", "==", "processing")
      .where("consent", "==", true)
      .where("lease_expires_at", "<=", now)
      .limit(25)
      .get(),
  ]);
  return [
    ...scheduled.docs.map((doc) => ({ref: doc.ref, status: "scheduled" as const})),
    ...retries.docs.map((doc) => ({ref: doc.ref, status: "retry" as const})),
    ...expired.docs.map((doc) => ({ref: doc.ref, status: "processing" as const})),
  ];
}

export const dispatchDueReminders = onSchedule(
  {
    schedule: "every minute",
    timeZone: "Asia/Kolkata",
    region: REGION,
    secrets: configuredSecrets(MSG91_AUTH_KEY),
    timeoutSeconds: 300,
    memory: "256MiB",
    maxInstances: 1,
  },
  async () => {
    const settings = await providerSelection();
    const due = await dueDocuments();
    for (let index = 0; index < due.length; index += 10) {
      await Promise.all(
        due
          .slice(index, index + 10)
          .map(({ref, status}) => deliver(ref, status, settings)),
      );
    }
    logger.info("Reminder dispatch completed", {processed: due.length});
  },
);

function safeEquals(left: string, right: string): boolean {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
}

function webhookValue(body: unknown, keys: string[]): string {
  if (!body || typeof body !== "object") return "";
  const record = body as Record<string, unknown>;
  for (const key of keys) {
    if (typeof record[key] === "string") return record[key] as string;
  }
  for (const value of Object.values(record)) {
    const nested = webhookValue(value, keys);
    if (nested) return nested;
  }
  return "";
}

export const msg91DeliveryWebhook = onRequest(
  {region: REGION, secrets: configuredSecrets(NOTIFICATION_WEBHOOK_SECRET)},
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).send("Method not allowed");
      return;
    }
    const supplied = asString(request.get("x-webhook-secret")) || asString(request.query.secret);
    const expectedSecret = credential(NOTIFICATION_WEBHOOK_SECRET);
    if (!supplied || !expectedSecret || !safeEquals(supplied, expectedSecret)) {
      response.status(401).send("Unauthorized");
      return;
    }
    const messageId = webhookValue(request.body, ["request_id", "message_id", "messageId"]);
    const providerStatus = webhookValue(request.body, ["status", "event", "delivery_status"])
      .toLowerCase();
    if (!messageId || !providerStatus) {
      response.status(400).send("message id and status are required");
      return;
    }
    const matches = await db
      .collectionGroup("reminders")
      .where("provider_message_id", "==", messageId)
      .limit(10)
      .get();
    const terminalStatus = providerStatus.includes("deliver")
      ? "delivered"
      : providerStatus.includes("read")
        ? "read"
        : providerStatus.includes("fail") || providerStatus.includes("reject")
          ? "failed"
          : "sent";
    await Promise.all(
      matches.docs.map((doc) =>
        doc.ref.update({
          status: terminalStatus,
          provider_status: providerStatus.slice(0, 100),
          delivery_updated_at: FieldValue.serverTimestamp(),
          updated_at: FieldValue.serverTimestamp(),
        }),
      ),
    );
    response.status(200).json({updated: matches.size});
  },
);

async function canManageClinic(uid: string, clinicId: string): Promise<boolean> {
  const snapshot = await db.collection("users").doc(uid).get();
  const data = snapshot.data() ?? {};
  const globalRole = asString(data.role).toLowerCase().replace(/[\s_-]+/g, "");
  if (["owner", "productowner", "platformowner", "superadmin"].includes(globalRole)) {
    return true;
  }
  const clinicIds = Array.isArray(data.clinic_ids) ? data.clinic_ids.map(String) : [];
  if (!clinicIds.includes(clinicId)) return false;
  const roles = data.clinic_roles as Record<string, unknown> | undefined;
  const roleLists = data.clinic_role_lists as Record<string, unknown> | undefined;
  const assignedRoles = Array.isArray(roleLists?.[clinicId])
    ? (roleLists?.[clinicId] as unknown[]).map((value) => asString(value))
    : [asString(roles?.[clinicId] ?? data.role)];
  return assignedRoles.some((value) =>
    ["admin", "administrator", "clinicadmin", "branchmanager"].includes(
      value.toLowerCase().replace(/[\s_-]+/g, ""),
    ));
}

export const sendTestNotification = onCall(
  {
    region: REGION,
    secrets: configuredSecrets(MSG91_AUTH_KEY),
  },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first");
    const input = request.data as Record<string, unknown>;
    const clinicId = asString(input.clinicId);
    if (!clinicId || !(await canManageClinic(request.auth.uid, clinicId))) {
      throw new HttpsError("permission-denied", "Clinic administrator access is required");
    }
    const clinic = await db.collection("clinics").doc(clinicId).get();
    try {
      const settings = await providerSelection();
      const override = input.provider === "msg91" || input.provider === "twilio"
        ? input.provider
        : undefined;
      const result = await sendNotification(
        {
          channel: channel(input.channel),
          recipient: asString(input.recipient),
          patientName: asString(input.patientName, "Test patient"),
          clinicName: asString(clinic.data()?.name, "Clinic"),
          message: asString(input.message, "This is a test clinic notification."),
          templateId: asString(input.templateId) || undefined,
          templateLanguage: asString(input.templateLanguage) || undefined,
        },
        settings,
        override,
      );
      return {ok: true, provider: result.provider, messageId: result.messageId};
    } catch (error) {
      const message = error instanceof Error ? error.message : "Notification failed";
      throw new HttpsError("failed-precondition", message);
    }
  },
);

export const twilioDeliveryWebhook = onRequest(
  {region: REGION, secrets: configuredSecrets(TWILIO_AUTH_TOKEN)},
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).send("Method not allowed");
      return;
    }
    const settings = await providerSelection();
    const callbackUrl = twilioConfig(settings).statusCallbackUrl;
    const signature = request.get("x-twilio-signature") ?? "";
    if (
      !callbackUrl ||
      !signature ||
      !validateTwilioWebhook(
        credential(TWILIO_AUTH_TOKEN),
        signature,
        callbackUrl,
        request.body as Record<string, unknown>,
      )
    ) {
      response.status(401).send("Unauthorized");
      return;
    }
    const messageId = asString(request.body?.MessageSid);
    const providerStatus = asString(request.body?.MessageStatus).toLowerCase();
    if (!messageId || !providerStatus) {
      response.status(400).send("MessageSid and MessageStatus are required");
      return;
    }
    const matches = await db
      .collectionGroup("reminders")
      .where("provider_message_id", "==", messageId)
      .limit(10)
      .get();
    const terminalStatus = providerStatus === "delivered"
      ? "delivered"
      : providerStatus === "read"
        ? "read"
        : ["failed", "undelivered", "canceled"].includes(providerStatus)
          ? "failed"
          : "sent";
    await Promise.all(
      matches.docs.map((doc) =>
        doc.ref.update({
          status: terminalStatus,
          provider_status: providerStatus.slice(0, 100),
          provider_error_code: asString(request.body?.ErrorCode).slice(0, 50),
          delivery_updated_at: FieldValue.serverTimestamp(),
          updated_at: FieldValue.serverTimestamp(),
        }),
      ),
    );
    response.status(200).send("OK");
  },
);

export const deleteAuthUserAfterProfileDeletion = onDocumentDeleted(
  {document: "users/{userId}", region: REGION},
  async (event) => {
    try {
      await getAuth().deleteUser(event.params.userId);
    } catch (error) {
      const code = (error as {code?: string}).code;
      if (code !== "auth/user-not-found") throw error;
    }
  },
);

export const cleanupDeletedClinic = onDocumentDeleted(
  {document: "clinics/{clinicId}", region: REGION},
  async (event) => {
    const clinicId = event.params.clinicId;
    const users = await db.collection("users")
      .where("clinic_ids", "array-contains", clinicId)
      .get();
    await Promise.all(users.docs.map((user) => user.ref.update({
      clinic_ids: FieldValue.arrayRemove(clinicId),
      [`clinic_roles.${clinicId}`]: FieldValue.delete(),
      [`clinic_role_lists.${clinicId}`]: FieldValue.delete(),
      updated_at: FieldValue.serverTimestamp(),
    })));
    if (event.data) await db.recursiveDelete(event.data.ref);
  },
);

async function provisionInvitation(
  invitation: {data(): Record<string, unknown>; ref: DocumentReference},
  clinicId: string,
): Promise<void> {
    const data = invitation.data() as Record<string, unknown>;
    const email = asString(data.email).toLowerCase();
    const role = asString(data.role, "doctor");
    const invitationRoles = Array.isArray(data.roles) && data.roles.length > 0
      ? data.roles.map((value) => asString(value)).filter(Boolean)
      : [role];
    if (!email || asString(data.status, "pending") !== "pending") return;

    let account;
    let isNewAccount = false;
    const temporaryPassword = `C!${randomBytes(9).toString("base64url")}9a`;
    try {
      try {
        account = await getAuth().getUserByEmail(email);
      } catch (error) {
        if ((error as {code?: string}).code !== "auth/user-not-found") throw error;
      }
      if (!account) {
        isNewAccount = true;
        account = await getAuth().createUser({
          email,
          password: temporaryPassword,
          emailVerified: false,
          displayName: email.split("@")[0],
        });
      } else {
        const existingProfile = await db.collection("users").doc(account.uid).get();
        isNewAccount = !existingProfile.exists;
      }
      if (isNewAccount) {
        await db.collection("users").doc(account.uid).set({
          name: account.displayName ?? email.split("@")[0],
          email,
          email_normalized: email,
          phone: "",
          role,
          clinic_ids: [],
          clinic_roles: {},
          clinic_role_lists: {},
          active_clinic_id: clinicId,
          status: "pending",
          must_change_password: true,
          invited_account: true,
          createdAt: FieldValue.serverTimestamp(),
          updated_at: FieldValue.serverTimestamp(),
        }, {merge: true});
      }

      const clinic = await db.collection("clinics").doc(clinicId).get();
      const clinicName = asString(clinic.data()?.name, "Clinic");
      const settings = await providerSelection();
      const result = await sendNotification({
        event: "member_invitation",
        channel: "email",
        recipient: email,
        patientName: account.displayName ?? "Team member",
        clinicName,
        message: "",
        templateLanguage: asString(data.locale, "en"),
        templateVariables: {
          action_url: await getAuth().generatePasswordResetLink(email),
          username: email,
          role,
          roles: invitationRoles.join(", "),
          approval_status: "pending",
        },
      }, settings);
      await invitation.ref.update({
        user_id: account.uid,
        notification_status: result.acceptedStatus === "disabled" ? "skipped" : "sent",
        notification_provider: result.provider,
        notification_message_id: result.messageId,
        notification_sent_at: FieldValue.serverTimestamp(),
        notification_error: FieldValue.delete(),
      });
      if (asString(data.phone)) {
        try {
          const sms = await sendNotification({
            event: "member_invitation", channel: "sms", recipient: asString(data.phone),
            patientName: account.displayName ?? "Team member", clinicName, message: "",
            templateLanguage: asString(data.locale, "en"),
            // An invitation phone has not been verified: never send it a password reset token.
            templateVariables: {roles: invitationRoles.join(", "), approval_status: "pending",
              action_url: CLINIC_APP_URL.value()},
          }, settings);
          await invitation.ref.update({notification_sms_status: sms.acceptedStatus === "disabled" ? "skipped" : "sent"});
        } catch {
          await invitation.ref.update({notification_sms_status: "failed"});
        }
      }
    } catch (error) {
      logger.error("Invited member provisioning failed", {clinicId});
      await invitation.ref.update({
        notification_status: "failed",
        notification_error: "Invitation delivery failed. Check notification providers and template settings.",
      });
    }
}

const invitationTriggerOptions = {
  document: "clinics/{clinicId}/team_invites/{inviteId}",
  region: REGION,
  secrets: configuredSecrets(MSG91_AUTH_KEY),
};

export const provisionInvitedMember = onDocumentCreated(
  invitationTriggerOptions,
  async (event) => {
    if (event.data) {
      await provisionInvitation(event.data, event.params.clinicId);
    }
  },
);

export const resendInvitedMemberEmail = onDocumentUpdated(
  invitationTriggerOptions,
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before || !after) return;
    const previousRequest = before.data().resend_requested_at;
    const currentRequest = after.data().resend_requested_at;
    const previousMillis = previousRequest instanceof Timestamp
      ? previousRequest.toMillis()
      : 0;
    const currentMillis = currentRequest instanceof Timestamp
      ? currentRequest.toMillis()
      : 0;
    if (currentMillis > previousMillis) {
      await provisionInvitation(after, event.params.clinicId);
    }
  },
);

export const approveInvitedMember = onDocumentUpdated(
  invitationTriggerOptions,
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before || !after || after.data().status !== "pending") return;
    const previousRequest = before.data().approval_requested_at;
    const currentRequest = after.data().approval_requested_at;
    const previousMillis = previousRequest instanceof Timestamp
      ? previousRequest.toMillis()
      : 0;
    const currentMillis = currentRequest instanceof Timestamp
      ? currentRequest.toMillis()
      : 0;
    if (currentMillis <= previousMillis) return;

    const clinicId = event.params.clinicId;
    const invitation = after.data() as Record<string, unknown>;
    const email = asString(invitation.email).toLowerCase();
    try {
      await provisionInvitation(after, clinicId);
      const users = await db.collection("users")
        .where("email_normalized", "==", email)
        .limit(1)
        .get();
      if (users.empty) {
        throw new Error("The invited account could not be provisioned");
      }
      const role = asString(invitation.role, "doctor");
      const roles = Array.isArray(invitation.roles) && invitation.roles.length > 0
        ? invitation.roles.map((value) => asString(value)).filter(Boolean)
        : [role];
      const user = users.docs[0];
      const batch = db.batch();
      batch.update(user.ref, {
        clinic_ids: FieldValue.arrayUnion(clinicId),
        [`clinic_roles.${clinicId}`]: role,
        [`clinic_role_lists.${clinicId}`]: roles,
        status: "approved",
        updated_at: FieldValue.serverTimestamp(),
      });
      batch.update(after.ref, {
        status: "approved",
        approval_status: "approved",
        approved_at: FieldValue.serverTimestamp(),
        approved_by: asString(invitation.approval_requested_by),
        approval_error: FieldValue.delete(),
      });
      await batch.commit();
    } catch (error) {
      logger.error("Invitation approval failed", {clinicId, email, error});
      await after.ref.update({
        approval_status: "failed",
        approval_error: (error instanceof Error ? error.message : "Unknown error")
          .slice(0, 500),
      });
    }
  },
);

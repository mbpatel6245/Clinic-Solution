import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {
  FieldValue,
  Timestamp,
  getFirestore,
  type DocumentReference,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {defineSecret, defineString} from "firebase-functions/params";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentDeleted} from "firebase-functions/v2/firestore";
import {
  ProviderError,
  sendWithMsg91,
  type Msg91Config,
  type NotificationChannel,
  type NotificationJob,
} from "./msg91.js";
import {timingSafeEqual} from "node:crypto";

initializeApp();
const db = getFirestore();

const MSG91_AUTH_KEY = defineSecret("MSG91_AUTH_KEY");
const NOTIFICATION_WEBHOOK_SECRET = defineSecret("NOTIFICATION_WEBHOOK_SECRET");
const DEFAULT_COUNTRY_CODE = defineString("MSG91_DEFAULT_COUNTRY_CODE", {default: "91"});
const SMS_TEMPLATE_ID = defineString("MSG91_SMS_TEMPLATE_ID", {default: ""});
const WHATSAPP_TEMPLATE_NAME = defineString("MSG91_WHATSAPP_TEMPLATE_NAME", {default: ""});
const WHATSAPP_NAMESPACE = defineString("MSG91_WHATSAPP_NAMESPACE", {default: ""});
const WHATSAPP_NUMBER = defineString("MSG91_WHATSAPP_INTEGRATED_NUMBER", {default: ""});
const EMAIL_TEMPLATE_ID = defineString("MSG91_EMAIL_TEMPLATE_ID", {default: ""});
const EMAIL_DOMAIN = defineString("MSG91_EMAIL_DOMAIN", {default: ""});
const EMAIL_FROM = defineString("MSG91_EMAIL_FROM", {default: ""});
const EMAIL_FROM_NAME = defineString("MSG91_EMAIL_FROM_NAME", {default: "Clinic"});

const MAX_ATTEMPTS = 3;
const REGION = "asia-south1";

function config(): Msg91Config {
  return {
    authKey: MSG91_AUTH_KEY.value(),
    defaultCountryCode: DEFAULT_COUNTRY_CODE.value(),
    smsTemplateId: SMS_TEMPLATE_ID.value(),
    whatsappTemplateName: WHATSAPP_TEMPLATE_NAME.value(),
    whatsappNamespace: WHATSAPP_NAMESPACE.value(),
    whatsappIntegratedNumber: WHATSAPP_NUMBER.value(),
    emailTemplateId: EMAIL_TEMPLATE_ID.value(),
    emailDomain: EMAIL_DOMAIN.value(),
    emailFrom: EMAIL_FROM.value(),
    emailFromName: EMAIL_FROM_NAME.value(),
  };
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
      provider: "msg91",
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
): Promise<void> {
  const claimed = await claim(ref, expectedStatus);
  if (!claimed) return;
  try {
    const result = await sendWithMsg91(claimed.job, config());
    await ref.update({
      status: "sent",
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
    secrets: [MSG91_AUTH_KEY],
    timeoutSeconds: 300,
    memory: "256MiB",
    maxInstances: 1,
  },
  async () => {
    const due = await dueDocuments();
    for (let index = 0; index < due.length; index += 10) {
      await Promise.all(
        due.slice(index, index + 10).map(({ref, status}) => deliver(ref, status)),
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
  {region: REGION, secrets: [NOTIFICATION_WEBHOOK_SECRET]},
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).send("Method not allowed");
      return;
    }
    const supplied = asString(request.get("x-webhook-secret")) || asString(request.query.secret);
    const expectedSecret = NOTIFICATION_WEBHOOK_SECRET.value();
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
  const role = asString(roles?.[clinicId] ?? data.role).toLowerCase().replace(/[\s_-]+/g, "");
  return ["admin", "administrator", "clinicadmin", "branchmanager"].includes(role);
}

export const sendTestNotification = onCall(
  {region: REGION, secrets: [MSG91_AUTH_KEY]},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first");
    const input = request.data as Record<string, unknown>;
    const clinicId = asString(input.clinicId);
    if (!clinicId || !(await canManageClinic(request.auth.uid, clinicId))) {
      throw new HttpsError("permission-denied", "Clinic administrator access is required");
    }
    const clinic = await db.collection("clinics").doc(clinicId).get();
    try {
      const result = await sendWithMsg91(
        {
          channel: channel(input.channel),
          recipient: asString(input.recipient),
          patientName: asString(input.patientName, "Test patient"),
          clinicName: asString(clinic.data()?.name, "Clinic"),
          message: asString(input.message, "This is a test clinic notification."),
          templateId: asString(input.templateId) || undefined,
          templateLanguage: asString(input.templateLanguage) || undefined,
        },
        config(),
      );
      return {ok: true, provider: result.provider, messageId: result.messageId};
    } catch (error) {
      const message = error instanceof Error ? error.message : "Notification failed";
      throw new HttpsError("failed-precondition", message);
    }
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

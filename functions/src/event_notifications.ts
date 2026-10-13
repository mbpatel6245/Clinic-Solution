import {deliveryDiagnostic} from "./delivery_diagnostics.js";
import {createHash} from "node:crypto";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, Timestamp, getFirestore, type DocumentReference} from "firebase-admin/firestore";
import {onDocumentCreated, onDocumentUpdated, onDocumentWritten} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import type {SecretParam} from "firebase-functions/params";
import {logger} from "firebase-functions";
import {ProviderError, validateEmail, type NotificationJob, type SendResult} from "./notification_provider.js";
import {appointmentEvent} from "./notification_templates.js";

const str = (value: unknown, fallback = "") => typeof value === "string" && value.trim() ? value.trim() : fallback;
const hash = (value: string) => createHash("sha256").update(value).digest("hex");
type Send = (job: NotificationJob) => Promise<SendResult>;

/** Deterministic IDs prevent Firestore event redelivery from creating duplicate jobs. */
export async function enqueueEvent(
  eventId: string, event: string, data: {
    email?: string; phone?: string; name: string; clinic: string; locale?: string;
    variables?: Record<string, string>;
  },
): Promise<void> {
  const db = getFirestore();
  for (const channel of ["email", "sms"] as const) {
    const recipient = channel === "email" ? data.email : data.phone;
    if (!recipient?.trim()) continue;
    const job: NotificationJob = {event, channel, recipient: recipient.trim(), patientName: data.name,
      clinicName: data.clinic, message: "", templateLanguage: data.locale || "en", templateVariables: data.variables ?? {}};
    try {
      await db.collection("notification_outbox").doc(`${hash(eventId)}_${channel}`).create({
        job, status: "queued", attempts: 0, next_attempt_at: Timestamp.now(), created_at: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if ((error as {code?: number}).code !== 6) throw error;
    }
  }
}

async function dispatch(ref: DocumentReference, send: Send): Promise<void> {
  const db = getFirestore();
  const claimed = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data();
    if (!data || !["queued", "retry", "processing"].includes(data.status) || data.next_attempt_at.toMillis() > Date.now()) return null;
    if (Number(data.attempts) >= 3) {
      transaction.update(ref, {status: "failed", error: "Delivery attempts exhausted", job: FieldValue.delete()});
      return null;
    }
    const attempts = Number(data.attempts ?? 0) + 1;
    transaction.update(ref, {status: "processing", attempts, next_attempt_at: Timestamp.fromMillis(Date.now() + 5 * 60_000)});
    return {job: data.job as NotificationJob, attempts};
  });
  if (!claimed) return;
  try {
    const result = await send(claimed.job);
    await ref.update({status: result.acceptedStatus === "disabled" ? "skipped" : "sent", provider: result.provider,
      message_id: result.messageId, sent_at: FieldValue.serverTimestamp(), job: FieldValue.delete(),
      event: claimed.job.event, channel: claimed.job.channel, error: FieldValue.delete(), error_code: FieldValue.delete()});
  } catch (error) {
    const retry = (!(error instanceof ProviderError) || error.retryable) && claimed.attempts < 3;
    const diagnostic = deliveryDiagnostic(error);
    // Provider responses can include sensitive reset links; store classified errors only.
    await ref.update({status: retry ? "retry" : "failed", error: diagnostic.message, error_code: diagnostic.code,
      next_attempt_at: Timestamp.fromMillis(Date.now() + 2 ** claimed.attempts * 60_000),
      ...(retry ? {} : {job: FieldValue.delete()}), event: claimed.job.event, channel: claimed.job.channel});
    logger.warn("Event notification failed", {event: claimed.job.event, channel: claimed.job.channel, retry, errorCode: diagnostic.code});
  }
}

export function createNotificationHandlers(send: Send, secrets: SecretParam[]) {
  const region = "asia-south1";
  const options = {region, secrets};
  const db = getFirestore();

  const dispatchEventNotifications = onSchedule({...options, schedule: "every minute", maxInstances: 1, timeoutSeconds: 300}, async () => {
    const due = await db.collection("notification_outbox").where("status", "in", ["queued", "retry", "processing"])
      .where("next_attempt_at", "<=", Timestamp.now()).orderBy("next_attempt_at").limit(100).get();
    for (let i = 0; i < due.size; i += 10) await Promise.all(due.docs.slice(i, i + 10).map((doc) => dispatch(doc.ref, send)));
  });

  const notifyAccountCreated = onDocumentCreated({document: "users/{userId}", region, retry: true}, async (event) => {
    const data = event.data?.data();
    if (!data || data.invited_account === true) return;
    // Auth is the source of truth for the email destination.
    const account = await getAuth().getUser(event.params.userId);
    await enqueueEvent(event.id, data.status === "pending" ? "account_pending" : "account_created", {
      email: account.email, phone: str(data.phone), name: str(data.name, "Member"),
      clinic: str(data.requested_clinic_name, "Clinic Solution"), locale: str(data.locale, "en"),
    });
  });

  const notifyAccountApproved = onDocumentUpdated({document: "users/{userId}", region, retry: true}, async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status || after.status !== "approved" || after.invited_account === true) return;
    const account = await getAuth().getUser(event.params.userId);
    const clinicId = str(after.active_clinic_id);
    const clinic = clinicId ? (await db.doc(`clinics/${clinicId}`).get()).data() : undefined;
    await enqueueEvent(event.id, "account_approved", {email: account.email, phone: str(after.phone),
      name: str(after.name, "Member"), clinic: str(clinic?.name, "Clinic Solution"), locale: str(after.locale, "en")});
  });

  const notifyMemberApproved = onDocumentUpdated({document: "clinics/{clinicId}/team_invites/{inviteId}", region, retry: true}, async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status || after.status !== "approved") return;
    const clinic = (await db.doc(`clinics/${event.params.clinicId}`).get()).data();
    await enqueueEvent(event.id, "member_approved", {email: str(after.email), phone: str(after.phone), name: "Team member",
      clinic: str(clinic?.name, "Clinic"), locale: str(after.locale, "en"), variables: {roles: Array.isArray(after.roles) ? after.roles.join(", ") : str(after.role, "Team member")}});
  });

  const notifyAppointmentChanged = onDocumentWritten({document: "clinics/{clinicId}/appointments/{appointmentId}", region, retry: true}, async (event) => {
    const after = event.data?.after.data();
    const before = event.data?.before.data();
    // Deleting a record is administrative cleanup, not a cancellation request.
    if (!after || after.notification_consent !== true) return;
    const kind = appointmentEvent(before, after);
    if (!kind) return;
    const clinic = (await db.doc(`clinics/${event.params.clinicId}`).get()).data();
    const scheduled = after.scheduled_at as Timestamp;
    let appointmentAt: string;
    try {
      appointmentAt = new Intl.DateTimeFormat("en-IN", {dateStyle: "medium", timeStyle: "short", timeZone: str(clinic?.timezone, "Asia/Kolkata")}).format(scheduled.toDate());
    } catch {
      appointmentAt = scheduled.toDate().toISOString();
    }
    await enqueueEvent(event.id, kind, {email: str(after.email), phone: str(after.phone),
      name: str(after.patient_name, "Patient"), clinic: str(clinic?.name, "Clinic"), locale: str(after.locale, "en"),
      variables: {appointment_at: `${appointmentAt} (${str(clinic?.timezone, "Asia/Kolkata")})`, appointment_id: event.params.appointmentId}});
  });

  const notifyInvoiceChanged = onDocumentWritten({document: "clinics/{clinicId}/invoices/{invoiceId}", region, retry: true}, async (event) => {
    const after = event.data?.after.data();
    const before = event.data?.before.data();
    if (!after || !str(after.patient_id)) return;
    const paid = Number(after.amount_paid ?? 0) - Number(before?.amount_paid ?? 0);
    if (before && paid <= 0) return;
    const patient = (await db.doc(`clinics/${event.params.clinicId}/patients/${after.patient_id}`).get()).data();
    if (!patient || patient.notification_consent !== true) return;
    const clinic = (await db.doc(`clinics/${event.params.clinicId}`).get()).data();
    const amount = (value: unknown) => `${str(clinic?.currency, "INR")} ${Number(value ?? 0).toFixed(2)}`;
    const recipient = {email: str(patient.email), phone: str(patient.phone), name: str(after.patient_name, "Patient"),
      clinic: str(clinic?.name, "Clinic"), locale: str(patient.locale, "en")};
    if (!before) await enqueueEvent(`${event.id}_invoice`, "invoice_created", {...recipient,
      variables: {invoice_id: event.params.invoiceId, amount: amount(after.total), balance: amount(after.balance)}});
    if (paid > 0) await enqueueEvent(`${event.id}_payment`, "payment_received", {...recipient,
      variables: {invoice_id: event.params.invoiceId, amount: amount(paid), balance: amount(after.balance)}});
  });

  const requestPasswordReset = onCall({region}, async (request) => {
    let email: string;
    try { email = validateEmail(str(request.data?.email)); } catch { throw new HttpsError("invalid-argument", "Enter a valid email address."); }
    const now = Date.now();
    const hour = Math.floor(now / 3_600_000);
    const ipRef = db.collection("notification_rate_limits").doc(hash(`ip:${request.rawRequest.ip}:${hour}`));
    const emailRef = db.collection("notification_rate_limits").doc(hash(`email:${email}:${hour}`));
    const allowed = await db.runTransaction(async (transaction) => {
      const ip = await transaction.get(ipRef);
      const address = await transaction.get(emailRef);
      if (Number(ip.data()?.count ?? 0) >= 20 || Number(address.data()?.count ?? 0) >= 5 || now - Number(address.data()?.last_at ?? 0) < 60_000) return false;
      for (const [ref, snapshot] of [[ipRef, ip], [emailRef, address]] as const) {
        transaction.set(ref, {count: Number(snapshot.data()?.count ?? 0) + 1, last_at: now, expires_at: Timestamp.fromMillis(now + 24 * 3_600_000)});
      }
      return true;
    });
    // Same response for unknown addresses and throttled requests prevents enumeration.
    if (!allowed) return {ok: true};
    try {
      const account = await getAuth().getUserByEmail(email);
      const actionUrl = await getAuth().generatePasswordResetLink(email);
      await enqueueEvent(`reset:${hash(email)}:${Math.floor(now / 60_000)}`, "password_reset", {
        email, phone: account.phoneNumber, name: account.displayName || "Member", clinic: "Clinic Solution",
        locale: str(request.data?.locale, "en"), variables: {action_url: actionUrl},
      });
    } catch (error) {
      if ((error as {code?: string}).code !== "auth/user-not-found") {
        logger.error("Password reset could not be queued");
        throw new HttpsError("unavailable", "Unable to request a reset right now. Please try again later.");
      }
    }
    return {ok: true};
  });

  return {dispatchEventNotifications, notifyAccountCreated, notifyAccountApproved, notifyMemberApproved,
    notifyAppointmentChanged, notifyInvoiceChanged, requestPasswordReset};
}

import {createHash} from "node:crypto";
import {FieldValue, Timestamp, getFirestore, type Firestore, type DocumentData} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const fail = (code: "invalid-argument" | "failed-precondition" | "permission-denied" | "aborted", message: string): never => { throw new HttpsError(code, message); };
const identifier = (v: unknown): string => typeof v === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(v) ? v : fail("invalid-argument", "Invalid identifier");
const text = (v: unknown, max = 20000): string => typeof v === "string" && v.length <= max ? v.trim() : fail("invalid-argument", "Invalid text field");
const normalize = (v: unknown) => String(v ?? "").toLowerCase().replace(/[\s_-]/g, "");
function canonical(v: unknown): string {
  if (Array.isArray(v)) return `[${v.map(canonical).join(",")}]`;
  if (v && typeof v === "object") return `{${Object.entries(v).sort(([a], [b]) => a.localeCompare(b)).map(([k, x]) => `${JSON.stringify(k)}:${canonical(x)}`).join(",")}}`;
  return JSON.stringify(v) ?? "null";
}
function date(v: unknown, optional = false): Timestamp | null {
  if (optional && (v === null || v === undefined || v === "")) return null;
  if (typeof v !== "string" || !/^\d{4}-\d\d-\d\dT/.test(v)) return fail("invalid-argument", "Invalid visit date");
  const parsed = new Date(v);
  if (!Number.isFinite(parsed.getTime())) return fail("invalid-argument", "Invalid visit date");
  return Timestamp.fromDate(parsed);
}
function record(input: unknown): DocumentData {
  if (!input || typeof input !== "object" || Array.isArray(input)) return fail("invalid-argument", "Missing clinical record");
  const value = input as Record<string, unknown>;
  const allowed = ["diagnoses", "complaints", "vitals", "investigation", "advice", "medicines", "visit_date", "follow_up_date"];
  if (Object.keys(value).some(k => !allowed.includes(k))) return fail("invalid-argument", "Unexpected clinical field");
  if (!Array.isArray(value.diagnoses) || value.diagnoses.length > 50 || !Array.isArray(value.medicines) || value.medicines.length > 50) return fail("invalid-argument", "Too many clinical entries");
  return {
    diagnoses: value.diagnoses.map(v => text(v, 256)), complaints: text(value.complaints), vitals: text(value.vitals), investigation: text(value.investigation), advice: text(value.advice),
    medicines: value.medicines.map(v => {
      if (!v || typeof v !== "object" || Array.isArray(v) || Object.keys(v).some(k => !["name", "dosage", "frequency", "duration", "instructions"].includes(k))) return fail("invalid-argument", "Invalid medicine");
      return Object.fromEntries(["name", "dosage", "frequency", "duration", "instructions"].map(k => [k, text((v as Record<string, unknown>)[k] ?? "", 4000)]));
    }).filter(v => v.name),
    visit_date: date(value.visit_date), follow_up_date: date(value.follow_up_date, true),
  };
}
function patientSnapshot(p: DocumentData): DocumentData {
  return Object.fromEntries(["first_name", "middle_name", "last_name", "gender", "phone", "address", "age", "age_unit", "date_of_birth", "abha_id", "allergies", "user_id", "email", "locale"].filter(k => p[k] !== undefined).map(k => [k, p[k]]));
}

/** Explicitly gated, online-only clinical finalization. Draft recovery is local;
 * signing/release are never inferred from a queued or timed-out client write.
 * All reads precede writes, and the parent revision serializes every transition.
 */
export function createClinicalHandler(db: Firestore) {
  return async (request: {auth?: {uid: string} | null; data: Record<string, unknown>}) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first");
    const input = request.data, uid = request.auth.uid;
    if (Buffer.byteLength(JSON.stringify(input)) > 256000) return fail("invalid-argument", "Clinical request is too large");
    const clinicId = identifier(input.clinicId), encounterId = identifier(input.encounterId), operationId = identifier(input.operationId);
    const kind = String(input.kind), expected = input.expectedRevision;
    if (!["saveDraft", "sign", "release", "revoke", "amend"].includes(kind) || !Number.isSafeInteger(expected) || Number(expected) < 0) return fail("invalid-argument", "Invalid clinical transition");
    const digest = createHash("sha256").update(canonical(input)).digest("hex");
    const clinicRef = db.doc(`clinics/${clinicId}`), encounterRef = clinicRef.collection("clinical_encounters").doc(encounterId);
    const receiptRef = clinicRef.collection("clinical_receipts").doc(`${uid}_${operationId}`);
    const projectionRef = clinicRef.collection("prescriptions").doc(encounterId), privateRef = clinicRef.collection("clinical_encounter_private").doc(encounterId);
    return db.runTransaction(async tx => {
      const [actor, clinicDoc, platform, encounterDoc, receipt, source, privateDoc, printDoc] = await tx.getAll(db.doc(`users/${uid}`), clinicRef, db.doc("platform_settings/modules"), encounterRef, receiptRef, projectionRef, privateRef, clinicRef.collection("settings").doc("prescription_print"));
      const user = actor.data() ?? {}, clinic = clinicDoc.data() ?? {};
      const roles = (user.clinic_role_lists?.[clinicId] ?? [user.clinic_roles?.[clinicId] ?? user.role]).map(normalize);
      if (!actor.exists || user.status !== "approved" || !(user.clinic_ids ?? []).includes(clinicId) || !roles.some((r: string) => ["doctor", "physician"].includes(r)) || clinic.active === false || !clinicDoc.exists ||
          (platform.data()?.disabled_modules ?? []).includes("clinical") || (clinic.enabled_modules?.length && !clinic.enabled_modules.includes("clinical"))) return fail("permission-denied", "Practitioner access is unavailable");
      if (clinic.clinical_v3 !== true) return fail("failed-precondition", "Clinical migration is not enabled");
      const e = encounterDoc.data();
      if (e && e.author_id !== uid) return fail("permission-denied", "Only the responsible practitioner can change this encounter");
      if (e && ((input.patientId !== undefined && input.patientId !== e.patient_id) || (input.appointmentId !== undefined && input.appointmentId !== e.appointment_id))) return fail("permission-denied", "Encounter identity cannot be changed");
      if (receipt.exists) {
        if (receipt.data()?.digest !== digest) throw new HttpsError("already-exists", "Operation ID was used with different details");
        return receipt.data()!.result;
      }
      if (Number(e?.revision ?? 0) !== expected) return fail("aborted", "The encounter changed. Reload and preserve your draft before reviewing again");
      if (!e && (kind !== "saveDraft" || source.exists)) return fail("failed-precondition", "Legacy encounters require an explicit migration; existing records cannot be claimed");
      const patientId = identifier(e?.patient_id ?? input.patientId);
      const patientRef = clinicRef.collection("patients").doc(patientId), patientDoc = await tx.get(patientRef);
      if (!patientDoc.exists && kind !== "revoke") return fail("failed-precondition", "Register or restore the patient record first");
      const patient = patientDoc.data() ?? {};
      const appointmentId = String(e?.appointment_id ?? input.appointmentId ?? "");
      const appointmentRef = appointmentId ? clinicRef.collection("appointments").doc(identifier(appointmentId)) : null;
      const appointment = appointmentRef ? await tx.get(appointmentRef) : null;
      if (kind !== "revoke" && appointmentRef && (!appointment?.exists || appointment.data()?.patient_id !== patientId || appointment.data()?.practitioner_id !== uid)) return fail("permission-denied", "The appointment is not assigned to this practitioner and patient");
      let update: DocumentData, result: DocumentData;
      const revision = Number(expected) + 1, version = Number(e?.version ?? 0);
      if (kind === "saveDraft") {
        if (e && e.state !== "draft") return fail("failed-precondition", "Start an audited amendment before editing a signed encounter");
        const snapshot = record(input.record);
        const patientView = patientSnapshot(patient);
        update = {author_id: uid, patient_id: patientId, patient: patientView, patient_fingerprint: createHash("sha256").update(canonical(patientView)).digest("hex"), appointment_id: appointmentId, revision, version, state: "draft", record: snapshot, updated_at: FieldValue.serverTimestamp()};
        if (!e) update.created_at = FieldValue.serverTimestamp();
        if (input.privateNotes !== undefined || !privateDoc.exists) tx.set(privateRef, {author_id: uid, body: text(input.privateNotes ?? ""), updated_at: FieldValue.serverTimestamp()});
        result = {state: "draft", revision, version};
      } else if (kind === "amend") {
        if (e?.state !== "signed") return fail("failed-precondition", "Only a signed encounter can be amended");
        const reason = text(input.reason, 1000);
        if (reason.length < 5) return fail("invalid-argument", "Explain the amendment");
        update = {state: "draft", revision, amendment_reason: reason, updated_at: FieldValue.serverTimestamp()};
        // Existing patient release stays on the last signed projection until the
        // next version is signed; drafts are never published by this operation.
        result = {state: "draft", revision, version};
      } else if (kind === "sign") {
        if (e?.state !== "draft" || input.identityReviewed !== true || input.medicationReviewed !== true || input.planReviewed !== true || input.finalAcknowledgement !== true) return fail("failed-precondition", "Review all clinical acknowledgements before signing");
        if (createHash("sha256").update(canonical(patientSnapshot(patient))).digest("hex") !== e.patient_fingerprint) return fail("aborted", "Patient identity or allergy information changed. Save and review the draft again");
        if (appointment && appointment.data()?.status !== "confirmed" && !(appointment.data()?.status === "completed" && appointment.data()?.prescription_id === encounterId)) return fail("failed-precondition", "Review the current queue visit before completion");
        const print = printDoc.data() ?? {}, signerName = String(user.display_name ?? user.name ?? ""), matchedLetterhead = signerName.length > 0 && String(print.clinician_name ?? "").trim() === signerName.trim();
        if (!signerName.trim()) return fail("failed-precondition", "Complete the practitioner identity before signing");
        const printContext = {...Object.fromEntries(["layout", "footer_note", "show_diagnoses", "show_vitals", "show_phone", "font_size", "margin_mm"].filter(k => print[k] !== undefined).map(k => [k, print[k]])), name: clinic.name ?? "Clinic", phone: clinic.phone ?? "", address: clinic.address ?? "", clinician_name: signerName, qualifications: matchedLetterhead ? print.qualifications ?? "" : "", registration: matchedLetterhead ? print.registration ?? "" : ""};
        const snapshot = {...e.record, patient: patientSnapshot(patient), patient_id: patientId, patient_user_id: String(patient.user_id ?? ""), appointment_id: appointmentId,
          patient_name_search: [patient.first_name, patient.middle_name, patient.last_name].filter(Boolean).join(" ").toLowerCase(), patient_phone_search: String(patient.phone ?? "").toLowerCase(),
          status: "pending", clinical_state: "signed", clinical_version: version + 1, clinical_author_id: uid, clinical_print_context: printContext, signed_at: FieldValue.serverTimestamp(), shared_with_patient: false,
          created_at: source.data()?.created_at ?? FieldValue.serverTimestamp(), updated_at: FieldValue.serverTimestamp()};
        tx.create(encounterRef.collection("versions").doc(String(version + 1)), {snapshot, author_id: uid, version: version + 1, review: {identity: true, medication: true, plan: true, final: true}, amendment_reason: e.amendment_reason ?? "", signed_at: FieldValue.serverTimestamp()});
        tx.create(privateRef.collection("versions").doc(String(version + 1)), {author_id: uid, body: privateDoc.data()?.body ?? "", signed_at: FieldValue.serverTimestamp()});
        tx.set(projectionRef, snapshot);
        tx.set(clinicRef.collection("clinical_notes").doc(encounterId), {patient_id: patientId, body: privateDoc.data()?.body ?? "", author_id: uid, updated_at: FieldValue.serverTimestamp()});
        if (appointmentRef && appointment?.data()?.status !== "completed") tx.update(appointmentRef, {status: "completed", completed_at: FieldValue.serverTimestamp(), prescription_id: encounterId, updated_at: FieldValue.serverTimestamp()});
        update = {state: "signed", revision, version: version + 1, released_version: 0, signed_at: FieldValue.serverTimestamp(), updated_at: FieldValue.serverTimestamp()};
        result = {state: "signed", revision, version: version + 1};
      } else if (kind === "revoke") {
        const reason = text(input.reason, 1000);
        if (!e || version < 1 || reason.length < 5 || input.revokeAcknowledgement !== true) return fail("failed-precondition", "Confirm the reason for revoking patient access");
        if (source.exists) tx.update(projectionRef, {shared_with_patient: false});
        update = {released_version: 0, revision, updated_at: FieldValue.serverTimestamp()};
        tx.create(clinicRef.collection("clinical_release_revocations").doc(`${uid}_${operationId}`), {encounter_id: encounterId, version, reason, author_id: uid, revoked_at: FieldValue.serverTimestamp()});
        result = {state: e.state, revision, version, released: false};
      } else {
        if (e?.state !== "signed" || !source.exists || source.data()?.clinical_version !== version || input.version !== version || input.releaseAcknowledgement !== true || clinic.share_prescriptions_with_patients !== true || !patient.user_id || input.recipientId !== patient.user_id || source.data()?.patient_user_id !== patient.user_id) return fail("failed-precondition", "Review the current signed version and linked patient account before release");
        const releaseRef = clinicRef.collection("clinical_releases").doc(`${encounterId}_${version}`);
        const [existing, recipient] = await tx.getAll(releaseRef, db.doc(`users/${identifier(patient.user_id)}`));
        if (!recipient.exists || normalize(recipient.data()?.role) !== "patient" || recipient.data()?.status !== "approved" || !(recipient.data()?.clinic_ids ?? []).includes(clinicId)) return fail("failed-precondition", "The linked patient account is not active in this clinic");
        if (!existing.exists) tx.create(releaseRef, {encounter_id: encounterId, version, patient_user_id: patient.user_id, author_id: uid, release_acknowledged: true, released_at: FieldValue.serverTimestamp()});
        tx.update(projectionRef, {shared_with_patient: true});
        update = {released_version: version, revision, updated_at: FieldValue.serverTimestamp()};
        result = {state: "signed", revision, version, released: true};
      }
      tx.set(encounterRef, update, {merge: true});
      tx.create(receiptRef, {actor_id: uid, digest, result, created_at: FieldValue.serverTimestamp()});
      tx.create(clinicRef.collection("audit_logs").doc(`clinical_${uid}_${operationId}`), {action: `clinical_${kind}`, actor_id: uid, encounter_id: encounterId, revision, version: result.version, created_at: FieldValue.serverTimestamp()});
      return result;
    });
  };
}

export const clinicalCommand = onCall({region: "asia-south1"}, request => createClinicalHandler(getFirestore())({auth: request.auth, data: request.data}));

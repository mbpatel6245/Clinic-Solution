import {applicationDefault} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {aiInstructions, createClinicalAiHandler, type AiInput} from "./clinical_ai.js";

const normalize = (value:unknown) => String(value ?? "").toLowerCase().replace(/[\s_-]+/g, "");
const env = process.env;
const handler = createClinicalAiHandler({
  enabled: () => env.CLINIC_AI_ENABLED === "true" && !!env.CLINIC_AI_MODEL && !!env.GCLOUD_PROJECT,
  authorize: async(uid,input) => {
    const db = getFirestore();
    const [user,clinic,platform] = await db.getAll(db.doc(`users/${uid}`),db.doc(`clinics/${input.clinicId}`),db.doc("platform_settings/modules"));
    const p = user.data() ?? {}, c = clinic.data() ?? {};
    const owner = ["platformowner","superadmin","owner"].includes(normalize(p.role));
    const member = Array.isArray(p.clinic_ids) && p.clinic_ids.includes(input.clinicId);
    const roles = p.clinic_role_lists?.[input.clinicId] ?? [p.clinic_roles?.[input.clinicId] ?? p.role];
    const clinician = Array.isArray(roles) && roles.some(r => ["doctor","physician","admin","administrator","clinicadmin","branchmanager"].includes(normalize(r)));
    const module = input.task === "lab_text" ? "laboratory" : "clinical";
    const enabledModules = Array.isArray(c.enabled_modules) && c.enabled_modules.length
      ? c.enabled_modules : ["patients","appointments","clinical","billing","expenses","reports"];
    return user.exists && clinic.exists && p.status === "approved" && c.active !== false &&
      c.ai_enabled === true && (owner || (member && clinician)) &&
      enabledModules.includes(module) &&
      !(platform.data()?.disabled_modules ?? []).includes(module);
  },
  reserve: async(uid,clinicId) => {
    const db = getFirestore();
    const day = new Date().toISOString().slice(0,10);
    // Server-only metadata; no prompts, results, names or patient identifiers.
    const refs = [db.doc(`clinics/${clinicId}/ai_usage/${day}`),db.doc(`clinics/${clinicId}/ai_usage/${day}_${uid}`)];
    await db.runTransaction(async tx => {
      const docs = await tx.getAll(...refs);
      if (docs.some((doc,i) => Number(doc.data()?.requests ?? 0) >= (i === 0 ? 100 : 20))) {
        throw new HttpsError("resource-exhausted", "The daily AI allowance has been reached.");
      }
      for (const ref of refs) tx.set(ref,{requests:FieldValue.increment(1),updated_at:FieldValue.serverTimestamp()},{merge:true});
    });
  },
  generate: generateVertexDraft,
});

async function generateVertexDraft(input:AiInput):Promise<unknown> {
  const project = env.GCLOUD_PROJECT!, model = env.CLINIC_AI_MODEL!;
  const location = env.CLINIC_AI_LOCATION ?? "asia-south1";
  if (!/^[a-zA-Z0-9._-]+$/.test(model) || !/^[a-z0-9-]+$/.test(project) || !/^[a-z0-9-]+$/.test(location)) {
    throw new HttpsError("failed-precondition", "AI configuration requires administrator review.");
  }
  const host = location === "global" ? "aiplatform.googleapis.com" : `${location}-aiplatform.googleapis.com`;
  const {access_token:token} = await applicationDefault().getAccessToken();
  try {
    const response = await fetch(`https://${host}/v1/projects/${project}/locations/${location}/publishers/google/models/${model}:generateContent`,{
      method:"POST",signal:AbortSignal.timeout(45_000),
      headers:{Authorization:`Bearer ${token}`,"Content-Type":"application/json"},
      body:JSON.stringify({systemInstruction:{parts:[{text:aiInstructions(input)}]},contents:[{role:"user",parts:[{text:input.text}]}],generationConfig:{temperature:0,maxOutputTokens:4096,responseMimeType:"application/json"}}),
    });
    if (!response.ok) throw new Error("Provider unavailable");
    const result = await response.json() as {candidates?: {finishReason?:string;content?:{parts?:{text?:string}[]}}[]};
    const candidate = result.candidates?.[0];
    if (candidate?.finishReason !== "STOP") throw new Error("Incomplete response");
    return JSON.parse(candidate.content?.parts?.map(part => part.text ?? "").join("") ?? "");
  } catch {
    // Never echo provider responses: they can contain clinical data.
    throw new HttpsError("unavailable", "AI assistance could not complete. Please try again or use manual entry.");
  }
}

export const prepareClinicalAiDraft = onCall({region:"asia-south1",enforceAppCheck:true,timeoutSeconds:60,maxInstances:2,concurrency:4},request => handler(request.auth?.uid,request.data));

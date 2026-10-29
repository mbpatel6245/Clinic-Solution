import {createHash} from "node:crypto";
import {HttpsError} from "firebase-functions/v2/https";

export const invalid = (message: string): never => { throw new HttpsError("invalid-argument", message); };
export const artifactId = (v: unknown): string => typeof v === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(v) ? v : invalid("Invalid identifier");
export const cleanText = (v: unknown, max = 4000): string => typeof v === "string" && v.length <= max ? v.trim() : invalid("Invalid text field");
export const requiredText = (v: unknown, max = 4000): string => cleanText(v, max) || invalid("Complete all required fields");
export function canonicalArtifact(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalArtifact).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.entries(value).sort(([a],[b]) => a.localeCompare(b)).map(([k,v]) => `${JSON.stringify(k)}:${canonicalArtifact(v)}`).join(",")}}`;
  return JSON.stringify(value) ?? "null";
}
export const artifactHash = (value: unknown): string => createHash("sha256").update(canonicalArtifact(value)).digest("hex");
export const normalizeArtifactText = (value: string): string => value.normalize("NFKC").trim().replace(/\s+/g," ").toLowerCase();
function object(value: unknown, allowed: string[]): Record<string,unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value) || Object.keys(value).some(k => !allowed.includes(k))) return invalid("Unexpected record fields");
  return value as Record<string,unknown>;
}
export function day(value: unknown): string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return invalid("Choose a valid collection date");
  const parsed=new Date(`${value}T00:00:00.000Z`);
  if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0,10)!==value) return invalid("Choose a valid collection date");
  return value;
}
export function instant(value: unknown): string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}(\d{3})?Z$/.test(value)) return invalid("Choose a valid date and time");
  const parsed=new Date(value), normalized=value.replace(/(\.\d{3})\d{3}Z$/,"$1Z");
  if (!Number.isFinite(parsed.getTime()) || parsed.toISOString()!==normalized) return invalid("Choose a valid date and time");
  return parsed.toISOString();
}
function identifiers(value: unknown, max: number): string[] {
  if (!Array.isArray(value) || value.length>max) return invalid("Too many selected records");
  const ids=value.map(artifactId);
  if (new Set(ids).size!==ids.length) return invalid("Repeated source record");
  return ids;
}
export type ArtifactKind="labOrder"|"labResult"|"carePlan";
export function artifactKind(value: unknown): ArtifactKind {
  if (!["labOrder","labResult","carePlan"].includes(String(value))) return invalid("Unsupported clinical document");
  return value as ArtifactKind;
}
export function artifactInput(kind: ArtifactKind, value: unknown): Record<string,any> {
  if (kind==="labOrder") {
    const v=object(value,["title","tests","planned_date","indication"]);
    if (!Array.isArray(v.tests) || !v.tests.length || v.tests.length>50) return invalid("Select at least one investigation");
    const tests=v.tests.map(t=>requiredText(t,200));
    if (new Set(tests.map(normalizeArtifactText)).size!==tests.length) return invalid("An investigation was selected more than once");
    return {title:requiredText(v.title,200),tests,planned_date:day(v.planned_date),indication:cleanText(v.indication??"",4000)};
  }
  if (kind==="labResult") {
    const v=object(value,["title","order_id","reported_date","source_reference","observations","review"]);
    if (!Array.isArray(v.observations) || !v.observations.length || v.observations.length>50) return invalid("Enter at least one result");
    const observations=v.observations.map(raw=>{
      const row=object(raw,["key","analyte","value","text_result","unit","lower","upper"]);
      const numeric=typeof row.value==="number" && Number.isFinite(row.value);
      const textual=typeof row.text_result==="string" && row.text_result.trim().length>0;
      if (numeric===textual) return invalid("Enter either a numeric or a text result");
      const bound=(v:unknown):number|null=>v===null||v===undefined?null:typeof v==="number"&&Number.isFinite(v)?v:invalid("Invalid reference range");
      const lower=bound(row.lower),upper=bound(row.upper);
      if ((!numeric&&(lower!==null||upper!==null)) || (lower!==null&&upper!==null&&lower>upper)) return invalid("Check the reported reference range");
      return {key:artifactId(row.key),analyte:requiredText(row.analyte,200),value:numeric?row.value:null,text_result:textual?requiredText(row.text_result,1000):"",unit:numeric?requiredText(row.unit,100):cleanText(row.unit??"",100),lower,upper};
    });
    if (new Set(observations.map(r=>r.key)).size!==observations.length) return invalid("Repeated result row");
    return {title:requiredText(v.title,200),order_id:v.order_id?artifactId(v.order_id):"",reported_date:day(v.reported_date),source_reference:requiredText(v.source_reference,1000),observations,review:requiredText(v.review,10000)};
  }
  const v=object(value,["title","instruction_indices","source_plan_id","vaccination_ids","verification_note"]);
  if (!Array.isArray(v.instruction_indices) || v.instruction_indices.length>100 || v.instruction_indices.some(i=>!Number.isInteger(i)||i<0||i>999) || new Set(v.instruction_indices).size!==v.instruction_indices.length) return invalid("Select the existing care instructions");
  const vaccinations=identifiers(v.vaccination_ids??[],50), note=cleanText(v.verification_note??"",4000);
  if (vaccinations.length&&!note) return invalid("Record how the vaccination history was checked");
  return {title:requiredText(v.title,200),instruction_indices:v.instruction_indices,source_plan_id:v.source_plan_id?artifactId(v.source_plan_id):"",vaccination_ids:vaccinations,verification_note:note};
}

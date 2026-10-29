import {createHash} from "node:crypto";
import {FieldValue, Timestamp, getFirestore, type Firestore, type DocumentData} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const norm=(v:unknown)=>String(v??"").toLowerCase().replace(/[\s_-]/g,"");
const clinical=["doctor","physician"], administrators=["platformowner","superadmin","owner","admin","administrator","clinicadmin","branchmanager"];
const id=(value:unknown):string=>{
  if(typeof value!=="string"||!/^[A-Za-z0-9_-]{1,128}$/.test(value)) throw new HttpsError("invalid-argument","Invalid identifier");
  return value;
};
const roles=(user:DocumentData,clinicId:string):string[]=>
  (user.clinic_role_lists?.[clinicId]??[user.clinic_roles?.[clinicId]??user.role]).map(norm);

export function localParts(instant:Date,zone:string):{day:string;minute:number;weekday:number}{
  const parts=Object.fromEntries(new Intl.DateTimeFormat("en-GB",{timeZone:zone,year:"numeric",month:"2-digit",day:"2-digit",hour:"2-digit",minute:"2-digit",hourCycle:"h23",weekday:"short"}).formatToParts(instant).map(p=>[p.type,p.value]));
  return {day:`${parts.year}-${parts.month}-${parts.day}`,minute:Number(parts.hour)*60+Number(parts.minute),weekday:["Mon","Tue","Wed","Thu","Fri","Sat","Sun"].indexOf(parts.weekday)+1};
}
export function overlaps(aStart:number,aEnd:number,bStart:number,bEnd:number):boolean{
  return aStart<bEnd&&bStart<aEnd;
}
function clock(value:unknown):number{
  if(typeof value!=="string"||!/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) throw new HttpsError("failed-precondition","Clinic hours need review");
  const [h,m]=value.split(":").map(Number);return h*60+m;
}
function sessions(value:unknown,open:number,close:number):number[][]{
  if(!Array.isArray(value)||!value.length||value.length>6) throw new HttpsError("invalid-argument","Choose one to six working sessions");
  const sorted=value.map(v=>{
    if(!Array.isArray(v)||v.length!==2||!v.every(Number.isInteger)||v[0]<open||v[1]>close||v[1]<=v[0]) throw new HttpsError("invalid-argument","Sessions must be within clinic hours");
    return v as number[];
  }).sort((a,b)=>a[0]-b[0]);
  if(sorted.some((v,i)=>i>0&&v[0]<sorted[i-1][1])) throw new HttpsError("invalid-argument","Sessions overlap");
  return sorted;
}
function access(user:DocumentData,clinic:DocumentData,clinicId:string,modules:DocumentData):string[]{
  const r=roles(user,clinicId), owner=administrators.slice(0,3).includes(norm(user.role));
  const member=(user.clinic_ids??[]).includes(clinicId)||(clinicId==="default-clinic"&&!(user.clinic_ids??[]).length);
  if(user.status!=="approved"||clinic.active===false||(!owner&&!member)||
    (!owner&&!r.some(v=>[...administrators,...clinical,"reception","receptionist"].includes(v)))||
    (modules.disabled_modules??[]).includes("appointments")||
    (clinic.enabled_modules?.length&&!clinic.enabled_modules.includes("appointments"))) {
    throw new HttpsError("permission-denied","Appointment access is unavailable");
  }
  return owner?[...r,"platformowner"]:r;
}

/** Server-only writer for clinics explicitly migrated to operational_v2.
 * A shared day guard serializes booking and availability even for empty queries.
 */
export function createOperationalHandler(db:Firestore,now:()=>Date=()=>new Date()){
  return async(request:{auth?:{uid:string}|null;data:Record<string,unknown>})=>{
    if(!request.auth) throw new HttpsError("unauthenticated","Sign in first");
    const uid=request.auth.uid, input=request.data, clinicId=id(input.clinicId), doctorId=id(input.doctorId), operationId=id(input.operationId);
    const kind=String(input.kind);
    if(!["book","availability","checkIn"].includes(kind)) throw new HttpsError("invalid-argument","Unsupported operation");
    const instant=new Date(String(input.start));
    if(!Number.isFinite(instant.getTime())) throw new HttpsError("invalid-argument","Invalid appointment date");
    const digest=createHash("sha256").update(JSON.stringify({kind,doctorId,patientId:input.patientId,start:instant.toISOString(),duration:input.duration,reason:input.reason,sessions:input.sessions,appointmentId:input.appointmentId,identityChecked:input.identityChecked,arrivalConsent:input.arrivalConsent})).digest("hex");
    const clinicRef=db.doc(`clinics/${clinicId}`), actorRef=db.doc(`users/${uid}`), doctorRef=db.doc(`users/${doctorId}`);
    const receiptRef=clinicRef.collection("operational_receipts").doc(`${uid}_${operationId}`);
    return db.runTransaction(async tx=>{
      const [actor,clinicDoc,doctor,platform,receipt]=await tx.getAll(actorRef,clinicRef,doctorRef,db.doc("platform_settings/modules"),receiptRef);
      const clinic=clinicDoc.data()??{};
      if(!actor.exists||!clinicDoc.exists) throw new HttpsError("permission-denied","Clinic access is unavailable");
      const r=access(actor.data()!,clinic,clinicId,platform.data()??{});
      if(clinic.operational_v2!==true) throw new HttpsError("failed-precondition","This clinic has not migrated scheduling yet");
      if(!doctor.exists||doctor.data()?.status!=="approved"||!(doctor.data()?.clinic_ids??[]).includes(clinicId)||
        !roles(doctor.data()!,clinicId).some(v=>clinical.includes(v))) throw new HttpsError("failed-precondition","Practitioner is unavailable");
      if(!r.some(v=>[...administrators,"reception","receptionist"].includes(v))&&uid!==doctorId) throw new HttpsError("permission-denied","Only your own schedule is available");
      if(receipt.exists){
        if(receipt.data()?.digest!==digest) throw new HttpsError("already-exists","Operation ID was used with different details");
        return receipt.data()!.result;
      }
      const zone=String(clinic.timezone??"Asia/Kolkata"), local=localParts(instant,zone);
      if(!((clinic.working_days??[1,2,3,4,5,6]) as number[]).includes(local.weekday)) throw new HttpsError("failed-precondition","Clinic is closed on this day");
      const open=clock(clinic.opening_time??"09:00"), close=clock(clinic.closing_time??"18:00");
      if(close<=open) throw new HttpsError("failed-precondition","Clinic hours need review");
      const guardRef=clinicRef.collection("operational_day_guards").doc(local.day);
      const availabilityRef=clinicRef.collection("practitioner_availability").doc(`${doctorId}_${local.day}`);
      const [guard,availability]=await tx.getAll(guardRef,availabilityRef);
      // The bounded query also includes legacy unassigned bookings, which block
      // every practitioner until explicitly assigned during migration.
      const existing=await tx.get(clinicRef.collection("appointments")
        .where("scheduled_at",">=",Timestamp.fromMillis(instant.getTime()-36*3600000))
        .where("scheduled_at","<=",Timestamp.fromMillis(instant.getTime()+36*3600000)));
      const appointments=existing.docs.filter(doc=>{
        const a=doc.data();return !["cancelled","no_show"].includes(a.status)&&
          (!a.practitioner_id||a.practitioner_id===doctorId)&&localParts(a.scheduled_at.toDate(),zone).day===local.day;
      });
      let result:Record<string,unknown>;
      if(kind==="availability"){
        if(uid!==doctorId) throw new HttpsError("permission-denied","Change only your own availability");
        const proposed=sessions(input.sessions,open,close);
        if(appointments.some(doc=>{
          const a=doc.data(), start=localParts(a.scheduled_at.toDate(),zone).minute,end=start+Number(a.duration_minutes??15);
          return !proposed.some(s=>s[0]<=start&&s[1]>=end);
        })) throw new HttpsError("failed-precondition","Availability would invalidate an existing appointment");
        tx.set(availabilityRef,{practitioner_id:doctorId,day:local.day,sessions:proposed,updated_by:uid,updated_at:FieldValue.serverTimestamp()});
        result={status:"saved",day:local.day};
      }else if(kind==="checkIn"){
        if(input.identityChecked!==true||input.arrivalConsent!==true) throw new HttpsError("failed-precondition","Confirm identity and arrival consent");
        const appointmentId=id(input.appointmentId),doc=existing.docs.find(d=>d.id===appointmentId),a=doc?.data();
        if(!doc||a?.practitioner_id!==doctorId||!["booked","confirmed"].includes(a.status)) throw new HttpsError("failed-precondition","Review the current appointment state");
        if(localParts(a.scheduled_at.toDate(),zone).day!==localParts(now(),zone).day) throw new HttpsError("failed-precondition","Check-in is available on the appointment day");
        tx.update(doc.ref,{status:"confirmed",arrival_at:a.arrival_at??FieldValue.serverTimestamp(),arrival_by:a.arrival_by??uid,identity_checked:true,updated_at:FieldValue.serverTimestamp()});
        result={status:"confirmed",appointmentId};
      }else{
        const patientId=id(input.patientId),duration=Number(input.duration),patientRef=clinicRef.collection("patients").doc(patientId);
        if(!Number.isInteger(duration)||duration<5||duration>120||duration%5!==0||local.minute%5!==0||instant.getUTCSeconds()!==0||instant.getUTCMilliseconds()!==0||instant<=now()||instant.getTime()>now().getTime()+366*86400000) throw new HttpsError("invalid-argument","Choose a future five-minute-aligned interval up to two hours");
        const reason=String(input.reason??"").trim();
        if(reason.length>500) throw new HttpsError("invalid-argument","Reason is too long");
        const endLocal=localParts(new Date(instant.getTime()+duration*60000),zone);
        if(endLocal.day!==local.day||endLocal.minute!==local.minute+duration) throw new HttpsError("failed-precondition","Choose an interval that does not cross a timezone transition");
        const active=sessions(availability.data()?.sessions??[[open,close]],open,close);
        if(!active.some(s=>s[0]<=local.minute&&s[1]>=local.minute+duration)||local.minute+duration>1440) throw new HttpsError("failed-precondition","The complete visit must fit a working session");
        if(appointments.some(doc=>{const a=doc.data(),start=a.scheduled_at.toMillis();return overlaps(instant.getTime(),instant.getTime()+duration*60000,start,start+Number(a.duration_minutes??15)*60000);})) throw new HttpsError("already-exists","This interval is no longer available");
        const patient=await tx.get(patientRef);
        if(!patient.exists) throw new HttpsError("not-found","Register the patient first");
        const p=patient.data()!,appointmentRef=clinicRef.collection("appointments").doc(operationId);
        const prior=await tx.get(appointmentRef);
        if(prior.exists) throw new HttpsError("already-exists","Appointment ID is already in use");
        tx.set(appointmentRef,{patient_id:patientId,patient_name:[p.first_name,p.middle_name,p.last_name].filter(Boolean).join(" "),phone:p.phone??"",email:p.email??"",locale:p.locale??"en",notification_consent:false,
          scheduled_at:Timestamp.fromDate(instant),duration_minutes:duration,practitioner_id:doctorId,
          practitioner_name:doctor.data()?.display_name??doctor.data()?.name??doctorId,reason,status:"booked",created_by:uid,
          doctor_fee:0,clinic_fee:0,amount_paid:0,created_at:FieldValue.serverTimestamp(),updated_at:FieldValue.serverTimestamp()});
        result={status:"booked",appointmentId:operationId};
      }
      tx.set(guardRef,{revision:Number(guard.data()?.revision??0)+1,updated_at:FieldValue.serverTimestamp()});
      tx.set(receiptRef,{digest,result,actor_id:uid,created_at:FieldValue.serverTimestamp()});
      tx.set(clinicRef.collection("audit_logs").doc(`${uid}_${operationId}`),{action:`operational_${kind}`,actor_id:uid,practitioner_id:doctorId,operation_id:operationId,created_at:FieldValue.serverTimestamp()});
      return result;
    });
  };
}

export const operationalCommand=onCall({region:"asia-south1"},request=>
  createOperationalHandler(getFirestore())({auth:request.auth,data:request.data}));

export const operationalPractitioners=onCall({region:"asia-south1"},async request=>{
  if(!request.auth) throw new HttpsError("unauthenticated","Sign in first");
  const db=getFirestore(),clinicId=id(request.data.clinicId);
  const [actor,clinic,platform]=await db.getAll(db.doc(`users/${request.auth.uid}`),db.doc(`clinics/${clinicId}`),db.doc("platform_settings/modules"));
  const r=access(actor.data()??{},clinic.data()??{},clinicId,platform.data()??{});
  const broad=r.some(v=>[...administrators,"reception","receptionist"].includes(v));
  const users=await db.collection("users").where("clinic_ids","array-contains",clinicId).get();
  return {enabled:clinic.data()?.operational_v2===true,doctors:users.docs.filter(u=>u.data().status==="approved"&&roles(u.data(),clinicId).some(v=>clinical.includes(v))&&(broad||u.id===request.auth!.uid))
    .map(u=>({id:u.id,name:u.data().display_name??u.data().name??u.id}))};
});

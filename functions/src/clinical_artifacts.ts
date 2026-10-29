import {HttpsError,onCall} from "firebase-functions/v2/https";
import {FieldValue,Timestamp,getFirestore,type Firestore,type DocumentData} from "firebase-admin/firestore";
import {artifactId,artifactKind,artifactInput,artifactHash,cleanText,requiredText,instant,normalizeArtifactText,type ArtifactKind} from "./clinical_artifact_model.js";

const reject=(message:string):never=>{throw new HttpsError("failed-precondition",message);};
const denied=():never=>{throw new HttpsError("permission-denied","Responsible practitioner access is required");};
const normalize=(v:unknown)=>String(v??"").toLowerCase().replace(/[\s_-]/g,"");
function iso(v:unknown):string {
  if(v instanceof Timestamp)return v.toDate().toISOString();
  if(v instanceof Date&&Number.isFinite(v.getTime()))return v.toISOString();
  return instant(v);
}
function patientView(p:DocumentData):DocumentData {
  return Object.fromEntries(["first_name","middle_name","last_name","age","age_unit","gender","phone","allergies"].filter(k=>p[k]!==undefined).map(k=>[k,p[k]]));
}
function clinicDay(now:Date,zone:string):string {
  try{return new Intl.DateTimeFormat("sv-SE",{timeZone:zone,year:"numeric",month:"2-digit",day:"2-digit"}).format(now);}catch{return reject("Review the clinic timezone");}
}
const moduleOn=(clinic:DocumentData,platform:DocumentData,module:string)=>!(platform.disabled_modules??[]).includes(module)&&(clinic.enabled_modules?.length?clinic.enabled_modules:["patients","appointments","clinical","billing","expenses","reports"]).includes(module);

/** Additive laboratory/care-copy protocol. Legacy records are never silently
 * claimed or interpreted as reviewed. Issuing and patient release are separate.
 */
export function createClinicalArtifactHandler(db:Firestore,now:()=>Date=()=>new Date()){
  return async(request:{auth?:{uid:string}|null;data:unknown})=>{
    if(!request.auth)throw new HttpsError("unauthenticated","Sign in first");
    if(!request.data||typeof request.data!=="object"||Array.isArray(request.data))throw new HttpsError("invalid-argument","Missing clinical request");
    const input=request.data as Record<string,unknown>,uid=request.auth.uid;
    if(Buffer.byteLength(JSON.stringify(input))>256000)throw new HttpsError("invalid-argument","Clinical request is too large");
    const clinicId=artifactId(input.clinicId),id=artifactId(input.artifactId),operationId=artifactId(input.operationId),kind=artifactKind(input.artifactKind),action=String(input.action),expected=input.expectedRevision;
    if(!["saveDraft","issue","amend","release","revoke","collect","cancel"].includes(action)||!Number.isSafeInteger(expected)||Number(expected)<0)throw new HttpsError("invalid-argument","Invalid clinical transition");
    const digest=artifactHash(input),clinicRef=db.doc(`clinics/${clinicId}`),ref=clinicRef.collection("clinical_artifacts").doc(id),copyRef=clinicRef.collection("clinical_artifact_copies").doc(id);
    const receiptRef=clinicRef.collection("clinical_artifact_receipts").doc(artifactHash([uid,operationId]));
    return db.runTransaction(async tx=>{
      const [actor,clinicDoc,platformDoc,parent,receipt,copy,printDoc]=await tx.getAll(db.doc(`users/${uid}`),clinicRef,db.doc("platform_settings/modules"),ref,receiptRef,copyRef,clinicRef.collection("settings").doc("prescription_print"));
      const user=actor.data()??{},clinic=clinicDoc.data()??{},platform=platformDoc.data()??{};
      const rawRoles=user.clinic_role_lists?.[clinicId]??[user.clinic_roles?.[clinicId]??user.role];
      if(!actor.exists||!clinicDoc.exists||user.status!=="approved"||!(user.clinic_ids??[]).includes(clinicId)||!Array.isArray(rawRoles)||!rawRoles.map(normalize).some(r=>["doctor","physician"].includes(r))||clinic.active===false||!moduleOn(clinic,platform,"clinical")||(kind!=="carePlan"&&!moduleOn(clinic,platform,"laboratory")))return denied();
      if(clinic.clinical_artifacts_v1!==true)return reject("Clinical document migration is not enabled");
      const e=parent.data();
      if(e&&(e.author_id!==uid||e.kind!==kind||(input.patientId!==undefined&&input.patientId!==e.patient_id)))return denied();
      if(receipt.exists){if(receipt.data()?.digest!==digest)throw new HttpsError("already-exists","Operation ID has different details");return receipt.data()!.result;}
      if(Number(e?.revision??0)!==expected)throw new HttpsError("aborted","The document changed. Preserve your draft and reload before reviewing again");
      if(!e&&(action!=="saveDraft"||copy.exists))return reject("Create a new clinical draft first");
      const patientId=artifactId(e?.patient_id??input.patientId),patientDoc=await tx.get(clinicRef.collection("patients").doc(patientId)),patient=patientDoc.data()??{};
      if(!patientDoc.exists&&!["revoke","cancel"].includes(action))return reject("The patient record is unavailable");
      const revision=Number(expected)+1,version=Number(e?.version??0);
      const encounterId=String(action==="saveDraft"?(input.encounterId??e?.encounter_id??""):(e?.encounter_id??""));
      let sourceEncounter:DocumentData|null=null;
      if(encounterId&&["saveDraft","issue"].includes(action)){const source=await tx.get(clinicRef.collection("clinical_encounters").doc(artifactId(encounterId)));sourceEncounter=source.data()??null;if(!source.exists||sourceEncounter?.author_id!==uid||sourceEncounter?.patient_id!==patientId)return denied();}
      const content=action==="saveDraft"?artifactInput(kind,input.record):e?.input;
      let sourceOrder:DocumentData|null=null,sourcePlan:DocumentData|null=null,vaccines:DocumentData[]=[],derived:DocumentData={};
      if(["saveDraft","issue"].includes(action)){
        if(!content)return reject("Save the draft before review");
        if(kind==="labOrder"){
          if(action==="issue"&&content.planned_date<clinicDay(now(),String(clinic.timezone??"Asia/Kolkata")))return reject("Review the requested collection date");
          derived={...content};
        }else if(kind==="labResult"){
          if(content.reported_date>clinicDay(now(),String(clinic.timezone??"Asia/Kolkata")))return reject("The report date cannot be in the future");
          if(content.order_id){
            const source=await tx.get(clinicRef.collection("clinical_artifacts").doc(content.order_id));sourceOrder=source.data()??null;
            if(!source.exists||sourceOrder?.kind!=="labOrder"||sourceOrder?.author_id!==uid||sourceOrder?.patient_id!==patientId)return denied();
            if(sourceOrder?.order_status==="cancelled")return reject("The linked order was cancelled");
            if(action==="issue"&&(sourceOrder?.order_status!=="collected"||content.reported_date<clinicDay(new Date(iso(sourceOrder.collected_at)),String(clinic.timezone??"Asia/Kolkata"))))return reject("Confirm collection and the correct report date before verification");
          }
          derived={title:content.title,reported_date:content.reported_date,source_reference:content.source_reference,observations:content.observations,review:content.review,order_id:content.order_id};
        }else{
          if(!sourceEncounter)return reject("Select the responsible practitioner's consultation");
          if(action==="issue"&&sourceEncounter.state!=="signed")return reject("Complete the source consultation before releasing its care instructions");
          const advice=String(sourceEncounter.record?.advice??"").split(/\r?\n/).map(v=>v.trim()).filter(Boolean);
          if(content.instruction_indices.some((i:number)=>i>=advice.length))return reject("The source advice changed. Select and review it again");
          if(content.source_plan_id){
            const source=await tx.get(clinicRef.collection("treatment_plans").doc(content.source_plan_id));sourcePlan=source.data()??null;
            if(!source.exists||sourcePlan?.patient_id!==patientId)return denied();
            if(sourcePlan?.status==="cancelled")return reject("The selected treatment plan is cancelled");
          }
          if(content.vaccination_ids.length){
            if(!moduleOn(clinic,platform,"vaccination"))return denied();
            const sources=await tx.getAll(...content.vaccination_ids.map((v:string)=>clinicRef.collection("vaccinations").doc(v)));
            vaccines=sources.map(source=>{
              const v:DocumentData=source.data()??{};
              if(!source.exists||v.patient_id!==patientId)return denied();
              const administered=iso(v.administered_at),dose=Number(v.dose_number);
              if(new Date(administered)>now()||!Number.isInteger(dose)||dose<1)return reject("Review the recorded vaccination details");
              return {vaccine:requiredText(v.vaccine,200),administered_at:administered,dose_number:dose,batch_number:cleanText(v.batch_number??"",200),manufacturer:cleanText(v.manufacturer??"",200),vaccinator:cleanText(v.vaccinator??"",200),route:cleanText(v.route??"",100),site:cleanText(v.site??"",100)};
            });
          }
          const rawSittings=sourcePlan?.sittings??[];
          if(!Array.isArray(rawSittings)||rawSittings.length>100)return reject("Review the treatment plan before release");
          const plan=sourcePlan?{name:requiredText(sourcePlan.name,200),status:sourcePlan.status??"active",sittings:rawSittings.map((s:DocumentData)=>({name:requiredText(s.name,200),scheduled_at:s.scheduled_at?iso(s.scheduled_at):null,completed:s.completed===true}))}:null;
          if(!content.instruction_indices.length&&!plan?.sittings.length)return reject("Select existing advice or a recorded treatment plan");
          derived={title:content.title,instructions:content.instruction_indices.map((i:number)=>advice[i]),follow_up_date:sourceEncounter.record?.follow_up_date?iso(sourceEncounter.record.follow_up_date):null,treatment_plan:plan,vaccinations:vaccines,source_encounter_version:Number(sourceEncounter.version??0)};
        }
      }
      const practitionerName=String(user.display_name??user.name??""),print=printDoc.data()??{},matched=practitionerName.trim().length>0&&String(print.clinician_name??"").trim()===practitionerName.trim();
      const context={clinic:{name:clinic.name??"Clinic",phone:clinic.phone??"",address:clinic.address??"",timezone:clinic.timezone??"Asia/Kolkata"},practitioner_name:practitionerName,registration:matched?String(print.registration??""):"",qualifications:matched?String(print.qualifications??""):""};
      const fingerprint=artifactHash({patient:patientView(patient),recipient:patient.user_id??"",context,record:derived,encounter:encounterId?{id:encounterId,version:sourceEncounter?.version,state:sourceEncounter?.state}:null,order:sourceOrder?{id:content.order_id,version:sourceOrder.version,status:sourceOrder.order_status,collected:sourceOrder.collected_at?iso(sourceOrder.collected_at):null}:null});
      let update:DocumentData,result:DocumentData;
      if(action==="saveDraft"){
        if(e&&e.state!=="draft")return reject("Start a reviewed amendment before changing an issued document");
        update={kind,author_id:uid,patient_id:patientId,patient:patientView(patient),patient_user_id:String(patient.user_id??""),encounter_id:encounterId,input:content,record:derived,context,fingerprint,state:"draft",revision,version,updated_at:FieldValue.serverTimestamp()};
        if(!e)update.created_at=FieldValue.serverTimestamp();
        result={state:"draft",revision,version};
      }else if(action==="issue"){
        if(e?.state!=="draft"||input.identityReviewed!==true||input.contentReviewed!==true||input.sourceReviewed!==true||input.finalAcknowledgement!==true)return reject("Complete all clinical review acknowledgements");
        if(!context.practitioner_name.trim())return reject("Complete the practitioner's identity");
        if(e.fingerprint!==fingerprint)throw new HttpsError("aborted","Patient or source information changed. Save and review the draft again");
        let orderKeyRef;
        if(kind==="labOrder"){
          orderKeyRef=clinicRef.collection("clinical_order_keys").doc(artifactHash([uid,patientId,content.planned_date,content.tests.map(normalizeArtifactText).sort()]));
          const key=await tx.get(orderKeyRef);
          if(key.exists&&key.data()?.artifact_id!==id){const other=await tx.get(clinicRef.collection("clinical_artifacts").doc(key.data()!.artifact_id));if(other.exists&&["ordered","collected"].includes(other.data()?.order_status)&&other.data()?.has_report!==true)throw new HttpsError("already-exists","A matching pending order already exists",{existingId:other.id});}
        }
        const snapshot={kind,record:derived,context,patient:patientView(patient),patient_id:patientId,patient_user_id:String(patient.user_id??""),version:version+1,issued_at:FieldValue.serverTimestamp()};
        tx.create(ref.collection("versions").doc(String(version+1)),{author_id:uid,snapshot,review:{identity:true,content:true,source:true,final:true},amendment_reason:e.amendment_reason??"",created_at:FieldValue.serverTimestamp()});
        tx.set(copyRef,{...snapshot,author_id:uid,shared:false,artifact_id:id});
        if(kind==="labOrder")tx.set(orderKeyRef!,{artifact_id:id,updated_at:FieldValue.serverTimestamp()});
        if(kind==="labResult"){
          for(const old of e.published_snapshot?.record?.observations??[])tx.set(clinicRef.collection("laboratory").doc(`ca_${artifactHash([id,version,old.key])}`),{superseded:true,clinical_artifact_id:id},{merge:true});
          for(const row of derived.observations)tx.create(clinicRef.collection("laboratory").doc(`ca_${artifactHash([id,version+1,row.key])}`),{record_type:row.value===null?"text_observation":"observation",patient_id:patientId,patient_name:[patient.first_name,patient.middle_name,patient.last_name].filter(Boolean).join(" "),analyte:row.analyte,value:row.value,text_result:row.text_result,unit:row.unit,lower:row.lower,upper:row.upper,notes:"",reported_at:derived.reported_date,reported_precision:"day",clinical_artifact_id:id,clinical_artifact_version:version+1,superseded:false,updated_at:FieldValue.serverTimestamp()});
          if(content.order_id)tx.update(clinicRef.collection("clinical_artifacts").doc(content.order_id),{has_report:true,report_ids:FieldValue.arrayUnion(id),updated_at:FieldValue.serverTimestamp()});
        }
        update={state:"issued",revision,version:version+1,released_version:0,published_snapshot:snapshot,issued_at:FieldValue.serverTimestamp(),updated_at:FieldValue.serverTimestamp()};
        if(kind==="labOrder"){update.order_status="ordered";update.has_report=false;}
        result={state:"issued",revision,version:version+1};
      }else if(action==="amend"){
        if(kind==="labOrder"||e?.state!=="issued")return reject("Only an issued report or care copy can be amended");
        const reason=requiredText(input.reason,1000);if(reason.length<5)return reject("Explain the amendment");
        update={state:"draft",revision,amendment_reason:reason,updated_at:FieldValue.serverTimestamp()};result={state:"draft",revision,version};
      }else if(action==="collect"){
        if(kind!=="labOrder"||e?.state!=="issued"||e.order_status!=="ordered"||input.collectionReviewed!==true)return reject("Confirm the current order before recording collection");
        const at=instant(input.collectedAt);if(new Date(at)>now()||Math.floor(new Date(at).getTime()/60000)<Math.floor(e.issued_at.toMillis()/60000))return reject("Review the actual collection time");
        update={revision,order_status:"collected",collected_at:Timestamp.fromDate(new Date(at)),collected_at_precision:"minute",collected_by:uid,updated_at:FieldValue.serverTimestamp()};result={state:"issued",orderStatus:"collected",revision,version};
      }else if(action==="cancel"){
        if(kind!=="labOrder"||!e||!(e.state==="draft"&&version===0)&&!(e.state==="issued"&&e.order_status==="ordered"))return reject("This order cannot be cancelled in its current state");
        const reason=requiredText(input.reason,1000);if(reason.length<5)return reject("Explain the cancellation");
        update={revision,state:"cancelled",order_status:"cancelled",cancellation_reason:reason,updated_at:FieldValue.serverTimestamp()};
        if(copy.exists)tx.update(copyRef,{shared:false});
        result={state:"cancelled",revision,version};
      }else if(action==="release"){
        const snapshot=copy.data();
        if(e?.state!=="issued"||!snapshot||snapshot.version!==version||input.version!==version||e.order_status==="cancelled"||clinic.share_clinical_artifacts_with_patients!==true||input.releaseAcknowledgement!==true||!patient.user_id||snapshot.patient_user_id!==patient.user_id||input.recipientId!==patient.user_id)return reject("Review the issued version, patient account and sharing permission");
        const recipient=await tx.get(db.doc(`users/${artifactId(patient.user_id)}`));
        if(!recipient.exists||recipient.data()?.role!=="patient"||recipient.data()?.status!=="approved"||!(recipient.data()?.clinic_ids??[]).includes(clinicId))return reject("The linked patient account is unavailable");
        tx.create(ref.collection("release_history").doc(artifactHash([uid,operationId])),{author_id:uid,version,action:"release",recipient_id:patient.user_id,created_at:FieldValue.serverTimestamp()});
        tx.update(copyRef,{shared:true});update={revision,released_version:version,updated_at:FieldValue.serverTimestamp()};result={state:"issued",released:true,revision,version};
      }else{
        if(!e||version<1||input.revokeAcknowledgement!==true)return reject("Confirm withdrawal of patient access");
        const reason=requiredText(input.reason,1000);if(reason.length<5)return reject("Explain the access withdrawal");
        if(copy.exists)tx.update(copyRef,{shared:false});
        tx.create(ref.collection("release_history").doc(artifactHash([uid,operationId])),{author_id:uid,version,action:"revoke",reason,created_at:FieldValue.serverTimestamp()});
        update={revision,released_version:0,updated_at:FieldValue.serverTimestamp()};result={state:e.state,released:false,revision,version};
      }
      tx.set(ref,update,{merge:true});tx.create(receiptRef,{actor_id:uid,digest,result,created_at:FieldValue.serverTimestamp()});
      tx.create(clinicRef.collection("audit_logs").doc(`artifact_${artifactHash([uid,operationId])}`),{action:`clinical_artifact_${action}`,kind,artifact_id:id,actor_id:uid,revision,version:result.version,created_at:FieldValue.serverTimestamp()});
      return result;
    });
  };
}
export const clinicalArtifactCommand=onCall({region:"asia-south1"},request=>createClinicalArtifactHandler(getFirestore())({auth:request.auth,data:request.data}));

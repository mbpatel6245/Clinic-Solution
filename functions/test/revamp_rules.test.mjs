import {readFile} from 'node:fs/promises';
import {before, after, test} from 'node:test';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, deleteDoc, getDoc, getDocs, collection, query, where, orderBy, setDoc, updateDoc, serverTimestamp, Timestamp, writeBatch} from 'firebase/firestore';

let env;
test('migrated scheduling blocks direct interval writes and protects receipts',async()=>{
  await env.withSecurityRulesDisabled(async context=>{
    const store=context.firestore();
    await setDoc(doc(store,'clinics/v2'),{active:true,operational_v2:true});
    await setDoc(doc(store,'users/v2-staff'),{role:'receptionist',status:'approved',clinic_ids:['v2']});
    await setDoc(doc(store,'clinics/v2/appointments/existing'),{patient_name:'Synthetic',phone:'',scheduled_at:Timestamp.now(),status:'booked',created_by:'v2-staff'});
    await setDoc(doc(store,'clinics/v2/operational_receipts/private'),{actor_id:'doctor',result:{status:'booked'}});
  });
  const staff=db('v2-staff');
  await assertFails(setDoc(doc(staff,'clinics/v2/appointments/new'),{patient_name:'Synthetic',phone:'',scheduled_at:Timestamp.now(),status:'booked',created_by:'v2-staff'}));
  await assertFails(updateDoc(doc(staff,'clinics/v2/appointments/existing'),{scheduled_at:Timestamp.now()}));
  await assertFails(updateDoc(doc(staff,'clinics/v2/appointments/existing'),{status:'confirmed'}));
    await assertSucceeds(updateDoc(doc(staff,'clinics/v2/appointments/existing'),{status:'no_show',updated_at:serverTimestamp()}));
    await env.withSecurityRulesDisabled(async context=>{
      await setDoc(doc(context.firestore(),'clinics/v2/appointments/arrived'),{status:'confirmed',scheduled_at:Timestamp.now(),arrival_at:Timestamp.now(),created_by:'v2-staff'});
      await setDoc(doc(context.firestore(),'clinics/v2/appointments/future'),{status:'booked',scheduled_at:Timestamp.fromMillis(Date.now()+86400000),created_by:'v2-staff'});
    });
    await assertFails(updateDoc(doc(staff,'clinics/v2/appointments/arrived'),{status:'no_show',updated_at:serverTimestamp()}));
    await assertFails(updateDoc(doc(staff,'clinics/v2/appointments/future'),{status:'no_show',updated_at:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(staff,'clinics/v2/appointments/existing'),{status:'cancelled',updated_at:serverTimestamp()}));
  await assertFails(setDoc(doc(staff,'clinics/v2/operational_day_guards/today'),{revision:99}));
  await assertFails(getDoc(doc(staff,'clinics/v2/operational_receipts/private')));
});
before(async () => {
  // A demo project cannot contact or mutate the production Firebase project.
  const address = process.env.FIRESTORE_EMULATOR_HOST;
  if (!address) throw new Error('Run with the Firestore emulator; production tests are forbidden.');
  const [host, port] = address.split(':');
  env = await initializeTestEnvironment({projectId:'demo-clinic-revamp',firestore:{host,port:Number(port),rules:await readFile(new URL('../../firestore.rules',import.meta.url),'utf8')}});
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const id of ['a','b']) await setDoc(doc(db,`clinics/${id}`),{active:true,share_prescriptions_with_patients:true});
    for (const [uid,role,clinic] of [['doctor','doctor','a'],['staff','receptionist','a'],['patient','patient','a'],['outsider','doctor','b'],['nurse','nurse','a'],['admin','clinic_admin','a']]) {
      await setDoc(doc(db,`users/${uid}`),{role,status:'approved',active_clinic_id:clinic,clinic_ids:[clinic],clinic_roles:{[clinic]:role}});
    }
    await setDoc(doc(db,'clinics/a/prescriptions/shared'),{shared_with_patient:true,patient_user_id:'patient'});
    await setDoc(doc(db,'clinics/a/clinical_notes/shared'),{body:'Private clinician note',patient_id:'patient',author_id:'doctor'});
  });
});
test('letterheads are clinic readable but only administrators can configure them',async()=>{
  const settings={layout:'classic',clinician_name:'Demo',qualifications:'',registration:'',footer_note:'',show_diagnoses:true,show_vitals:true,show_phone:true,font_size:12,margin_mm:18};
  await assertSucceeds(setDoc(doc(db('admin'),'clinics/a/settings/prescription_print'),settings));
  await assertSucceeds(getDoc(doc(db('doctor'),'clinics/a/settings/prescription_print')));
  for(const uid of ['doctor','staff','patient','outsider']) await assertFails(setDoc(doc(db(uid),'clinics/a/settings/prescription_print'),settings));
  for(const uid of ['staff','patient','outsider']) await assertFails(getDoc(doc(db(uid),'clinics/a/settings/prescription_print')));
  await assertFails(setDoc(doc(db('admin'),'clinics/a/settings/prescription_print'),{...settings,patient_id:'sensitive'}));
  await assertFails(setDoc(doc(db('admin'),'clinics/a/settings/prescription_print'),{...settings,font_size:0}));
});
test('sitting logs require atomic progress, protect private notes and forbid rewrites',async()=>{
  const planPath='clinics/a/treatment_plans/log-review';
  const sitting={name:'Demo sitting',scheduled_at:Timestamp.now(),completed:false,notes:''};
  const plan={name:'Demo',patient_id:'demo',patient_name:'Demo',sittings:[sitting],status:'active',notes:''};
  await assertSucceeds(setDoc(doc(db('doctor'),planPath),plan));
  const entry={sitting_index:0,work_done:'Synthetic review',notes:'Private demo notes',performed_at:Timestamp.now(),author_id:'doctor',recorded_at:serverTimestamp()};
  await assertFails(setDoc(doc(db('doctor'),`${planPath}/sitting_logs/0`),entry));
  const writer=db('doctor');
  const batch=writeBatch(writer);batch.update(doc(writer,planPath),{sittings:[{...sitting,completed:true}]});batch.set(doc(writer,`${planPath}/sitting_logs/0`),entry);
  await assertSucceeds(batch.commit());
  await assertSucceeds(getDoc(doc(db('doctor'),`${planPath}/sitting_logs/0`)));
  for(const uid of ['staff','patient','outsider','nurse'])await assertFails(getDoc(doc(db(uid),`${planPath}/sitting_logs/0`)));
  await assertFails(updateDoc(doc(db('doctor'),`${planPath}/sitting_logs/0`),{notes:'Changed'}));
  await assertFails(setDoc(doc(db('doctor'),`${planPath}/sitting_logs/1`),{...entry,sitting_index:1,author_id:'someone-else'}));
});
after(async()=>{await env?.cleanup();});
test('reviewed lab and care copies enforce author-only drafts, separate patient sharing and protected numeric projections',async()=>{
  const base='clinics/artifacts-rules';
  await env.withSecurityRulesDisabled(async context=>{
    const store=context.firestore();
    await setDoc(doc(store,base),{active:true,clinical_artifacts_v1:true,enabled_modules:['clinical','laboratory'],share_prescriptions_with_patients:true,share_clinical_artifacts_with_patients:true});
    for(const [uid,role] of [['artifact-doctor','doctor'],['artifact-other','doctor'],['artifact-admin','clinic_admin'],['artifact-patient','patient']])await setDoc(doc(store,`users/${uid}`),{role,status:'approved',clinic_ids:['artifacts-rules']});
    await setDoc(doc(store,`${base}/clinical_artifacts/care`),{author_id:'artifact-doctor',patient_id:'synthetic',state:'draft',input:{verification_note:'PRIVATE SOURCE NOTE'}});
    await setDoc(doc(store,`${base}/clinical_artifacts/care/versions/1`),{author_id:'artifact-doctor',snapshot:{record:{instructions:['Selected existing advice']}}});
    await setDoc(doc(store,`${base}/clinical_artifact_copies/care`),{kind:'carePlan',version:1,shared:true,patient_user_id:'artifact-patient',issued_at:Timestamp.now(),record:{instructions:['Selected existing advice']}});
    await setDoc(doc(store,`${base}/laboratory/bridge`),{record_type:'observation',clinical_artifact_id:'care',clinical_artifact_version:1,value:4,unit:'synthetic',superseded:false});
  });
  await assertSucceeds(getDoc(doc(db('artifact-doctor'),`${base}/clinical_artifacts/care`)));
  await assertSucceeds(getDoc(doc(db('artifact-doctor'),`${base}/clinical_artifact_copies/care`)));
  await assertSucceeds(getDoc(doc(db('artifact-patient'),`${base}/clinical_artifact_copies/care`)));
  await assertSucceeds(getDocs(query(collection(db('artifact-patient'),`${base}/clinical_artifact_copies`),where('patient_user_id','==','artifact-patient'),where('shared','==',true),orderBy('issued_at','desc'))));
  for(const uid of ['artifact-patient','artifact-admin','artifact-other']){
    await assertFails(getDoc(doc(db(uid),`${base}/clinical_artifacts/care`)));
    await assertFails(getDoc(doc(db(uid),`${base}/clinical_artifacts/care/versions/1`)));
  }
  await assertFails(setDoc(doc(db('artifact-doctor'),`${base}/clinical_artifacts/forged`),{author_id:'artifact-doctor'}));
  await assertFails(updateDoc(doc(db('artifact-doctor'),`${base}/clinical_artifact_copies/care`),{shared:false}));
  await assertFails(updateDoc(doc(db('artifact-doctor'),`${base}/laboratory/bridge`),{value:99}));
  await assertFails(deleteDoc(doc(db('artifact-admin'),`${base}/laboratory/bridge`)));
  await assertFails(setDoc(doc(db('artifact-doctor'),`${base}/laboratory/forged`),{record_type:'observation',clinical_artifact_id:'care'}));
  await assertFails(updateDoc(doc(db('artifact-admin'),base),{clinical_artifacts_v1:false}));
  await assertSucceeds(updateDoc(doc(db('artifact-admin'),base),{share_clinical_artifacts_with_patients:false,updated_at:serverTimestamp()}));
  await assertSucceeds(getDocs(query(collection(db('artifact-admin'),`${base}/clinical_artifact_copies`),where('shared','==',true))));
  await assertFails(getDoc(doc(db('artifact-patient'),`${base}/clinical_artifact_copies/care`)));
  await assertSucceeds(updateDoc(doc(db('artifact-admin'),`${base}/clinical_artifact_copies/care`),{shared:false,updated_at:serverTimestamp()}));
  await assertFails(updateDoc(doc(db('artifact-admin'),`${base}/clinical_artifact_copies/care`),{shared:true,updated_at:serverTimestamp()}));
});
const db = uid => env.authenticatedContext(uid).firestore();

test('clinical V3 versions are server-only, private notes are author scoped, and patient release cannot be forged',async()=>{
  await env.withSecurityRulesDisabled(async context=>{
    const store=context.firestore();
    await setDoc(doc(store,'clinics/clinical-v3'),{active:true,clinical_v3:true,share_prescriptions_with_patients:true});
    for (const [uid,role] of [['v3-doctor','doctor'],['v3-other','doctor'],['v3-admin','admin'],['v3-patient','patient'],['v3-pharmacy','pharmacist']]) await setDoc(doc(store,`users/${uid}`),{role,status:'approved',clinic_ids:['clinical-v3']});
    await setDoc(doc(store,'clinics/clinical-v3/clinical_encounters/rx'),{author_id:'v3-doctor',state:'signed',revision:2,version:1});
    await setDoc(doc(store,'clinics/clinical-v3/clinical_encounters/rx/versions/1'),{author_id:'v3-doctor',snapshot:{advice:'Immutable synthetic advice'}});
    await setDoc(doc(store,'clinics/clinical-v3/clinical_encounter_private/rx'),{author_id:'v3-doctor',body:'Private synthetic context'});
    await setDoc(doc(store,'clinics/clinical-v3/clinical_notes/rx'),{author_id:'v3-doctor',body:'Private synthetic context'});
    await setDoc(doc(store,'clinics/clinical-v3/prescriptions/rx'),{clinical_state:'signed',clinical_version:1,clinical_author_id:'v3-doctor',shared_with_patient:false,patient_user_id:'v3-patient',status:'pending',visit_date:Timestamp.now()});
  });
  const base='clinics/clinical-v3';
  await assertSucceeds(getDoc(doc(db('v3-doctor'),`${base}/clinical_encounters/rx/versions/1`)));
  for (const uid of ['v3-other','v3-admin','v3-patient']) {
    await assertFails(getDoc(doc(db(uid),`${base}/clinical_encounters/rx/versions/1`)));
    await assertFails(getDoc(doc(db(uid),`${base}/clinical_encounter_private/rx`)));
    await assertFails(getDoc(doc(db(uid),`${base}/clinical_notes/rx`)));
  }
  await assertFails(setDoc(doc(db('v3-doctor'),`${base}/clinical_encounters/rx/versions/2`),{author_id:'v3-doctor'}));
  await assertFails(setDoc(doc(db('v3-doctor'),`${base}/prescriptions/new`),{patient_id:'synthetic'}));
  await assertFails(updateDoc(doc(db('v3-doctor'),`${base}/prescriptions/rx`),{advice:'Overwrite signed content'}));
  await assertFails(updateDoc(doc(db('v3-admin'),`${base}/prescriptions/rx`),{shared_with_patient:true}));
  await assertFails(getDoc(doc(db('v3-patient'),`${base}/prescriptions/rx`)));
  await assertSucceeds(updateDoc(doc(db('v3-pharmacy'),`${base}/prescriptions/rx`),{status:'dispensed',updated_at:serverTimestamp()}));
  await env.withSecurityRulesDisabled(context=>updateDoc(doc(context.firestore(),`${base}/prescriptions/rx`),{shared_with_patient:true}));
  await assertSucceeds(getDoc(doc(db('v3-patient'),`${base}/prescriptions/rx`)));
  await assertSucceeds(getDocs(query(collection(db('v3-patient'),`${base}/prescriptions`),where('patient_user_id','==','v3-patient'),where('shared_with_patient','==',true),orderBy('visit_date','desc'))));
  await env.withSecurityRulesDisabled(context=>updateDoc(doc(context.firestore(),base),{share_prescriptions_with_patients:false}));
  await assertFails(getDoc(doc(db('v3-patient'),`${base}/prescriptions/rx`)));
  await assertSucceeds(updateDoc(doc(db('v3-admin'),`${base}/prescriptions/rx`),{shared_with_patient:false,updated_at:serverTimestamp()}));
});

test('private clinical notes stay hidden even when a prescription is shared',async()=>{
  await assertSucceeds(getDoc(doc(db('patient'),'clinics/a/prescriptions/shared')));
  for (const uid of ['patient','staff','outsider','nurse']) await assertFails(getDoc(doc(db(uid),'clinics/a/clinical_notes/shared')));
  await assertSucceeds(getDoc(doc(db('doctor'),'clinics/a/clinical_notes/shared')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'clinics/a/clinical_notes/shared')));
});
test('only authorized clinicians can create private notes and author identity is enforced',async()=>{
  const payload={body:'Review only',patient_id:'demo',author_id:'doctor',updated_at:serverTimestamp()};
  await assertSucceeds(setDoc(doc(db('doctor'),'clinics/a/clinical_notes/new'),payload));
  await assertFails(setDoc(doc(db('staff'),'clinics/a/clinical_notes/frontdesk'),{...payload,author_id:'staff'}));
  await assertFails(setDoc(doc(db('doctor'),'clinics/a/clinical_notes/spoof'),{...payload,author_id:'someone-else'}));
});
test('templates reject patient identifiers and deny front desk writes',async()=>{
  const payload={name:'Reusable protocol',diagnoses:[],medicines:[],complaints:'',investigation:'',advice:'',updated_at:serverTimestamp()};
  await assertSucceeds(setDoc(doc(db('doctor'),'clinics/a/prescription_templates/good'),payload));
  await assertFails(setDoc(doc(db('doctor'),'clinics/a/prescription_templates/leak'),{...payload,patient_id:'patient'}));
  await assertFails(setDoc(doc(db('staff'),'clinics/a/prescription_templates/staff'),payload));
  await assertFails(getDoc(doc(db('outsider'),'clinics/a/prescription_templates/good')));
});
test('treatment plans are clinic scoped and unavailable to reception and patients',async()=>{
  const payload={name:'Demo plan',patient_id:'demo',patient_name:'Demo',sittings:[],notes:'',updated_at:serverTimestamp()};
  await assertSucceeds(setDoc(doc(db('doctor'),'clinics/a/treatment_plans/good'),payload));
  for (const uid of ['staff','patient','outsider']) await assertFails(getDoc(doc(db(uid),'clinics/a/treatment_plans/good')));
  await assertFails(setDoc(doc(db('doctor'),'clinics/b/treatment_plans/other'),payload));
});
test('team messages permit clinic staff but reject patients, other clinics and spoofed senders',async()=>{
  const payload={text:'Ready for next appointment',sender_id:'staff',sender_name:'Front desk',sent_at:serverTimestamp()};
  await assertSucceeds(setDoc(doc(db('staff'),'clinics/a/staff_messages/one'),payload));
  await assertSucceeds(getDoc(doc(db('doctor'),'clinics/a/staff_messages/one')));
  for(const uid of ['patient','outsider'])await assertFails(getDoc(doc(db(uid),'clinics/a/staff_messages/one')));
  await assertFails(setDoc(doc(db('staff'),'clinics/a/staff_messages/spoof'),{...payload,sender_id:'doctor'}));
  await assertFails(updateDoc(doc(db('staff'),'clinics/a/staff_messages/one'),{text:'Changed'}));
  await assertFails(setDoc(doc(db('staff'),'clinics/a/staff_messages/oversize'),{...payload,text:'x'.repeat(1001)}));
});
test('AI quota metadata cannot be read or overwritten by clinic clients',async()=>{
  await env.withSecurityRulesDisabled(context=>setDoc(doc(context.firestore(),'clinics/a/ai_usage/2026-10-19'),{requests:3}));
  for(const uid of ['doctor','staff','patient','outsider']) {
    await assertFails(getDoc(doc(db(uid),'clinics/a/ai_usage/2026-10-19')));
    await assertFails(setDoc(doc(db(uid),'clinics/a/ai_usage/2026-10-19'),{requests:0}));
  }
});

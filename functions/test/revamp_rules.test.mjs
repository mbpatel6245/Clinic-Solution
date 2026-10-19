import {readFile} from 'node:fs/promises';
import {before, after, test} from 'node:test';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, serverTimestamp, Timestamp, writeBatch} from 'firebase/firestore';

let env;
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
const db = uid => env.authenticatedContext(uid).firestore();

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

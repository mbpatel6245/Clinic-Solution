const {test,after}=require('node:test');
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getFirestore,Timestamp}=require('firebase-admin/firestore');
const {createClinicalHandler}=require('../lib/clinical_lifecycle.js');
if(!/^(localhost|127\.0\.0\.1):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST??''))throw Error('Local Firestore emulator required');
const app=initializeApp({projectId:'demo-clinic-clinical'}),db=getFirestore(app);
after(()=>deleteApp(app));
async function fixture(){
  const clinicId=`c-${randomUUID()}`,uid=`u-${randomUUID()}`,other=`u-${randomUUID()}`;
  await Promise.all([
    db.doc(`clinics/${clinicId}`).set({active:true,clinical_v3:true,enabled_modules:['clinical'],share_prescriptions_with_patients:true}),
    db.doc(`users/${uid}`).set({status:'approved',role:'doctor',display_name:'Synthetic Doctor',clinic_ids:[clinicId]}),
    db.doc(`users/${other}`).set({status:'approved',role:'doctor',clinic_ids:[clinicId]}),
    db.doc('users/patient-login').set({status:'approved',role:'patient',clinic_ids:[clinicId]}),
    db.doc(`clinics/${clinicId}/patients/patient`).set({first_name:'Synthetic',last_name:'Patient',user_id:'patient-login',allergies:['Synthetic allergy']}),
    db.doc(`clinics/${clinicId}/appointments/queue`).set({patient_id:'patient',practitioner_id:uid,status:'confirmed',arrival_at:Timestamp.now()}),
  ]);
  const run=createClinicalHandler(db),record={diagnoses:['Synthetic assessment'],complaints:'Synthetic concern',vitals:'Recorded example',investigation:'',advice:'Synthetic advice',medicines:[{name:'Synthetic medicine',dosage:'Example',frequency:'Example',duration:'Example',instructions:'Layout only'}],visit_date:'2026-10-28T09:00:00.000Z',follow_up_date:null};
  const input={clinicId,encounterId:'encounter',operationId:'save-1',kind:'saveDraft',patientId:'patient',appointmentId:'queue',expectedRevision:0,record,privateNotes:'PRIVATE SYNTHETIC NOTE'};
  const call=(data={})=>run({auth:{uid},data:{...input,...data}});
  const transition=(kind,expectedRevision,extra={})=>call({kind,expectedRevision,operationId:`${kind}-${expectedRevision}`,...extra});
  const sign=(revision=1)=>transition('sign',revision,{identityReviewed:true,medicationReviewed:true,planReviewed:true,finalAcknowledgement:true});
  return {uid,other,clinicId,input,run,call,transition,sign,ref:db.doc(`clinics/${clinicId}/clinical_encounters/encounter`),projection:db.doc(`clinics/${clinicId}/prescriptions/encounter`)};
}
test('reviewed finalization is idempotent, keeps immutable public/private versions and completes the assigned queue atomically',async()=>{
  const f=await fixture();assert.equal((await f.call()).state,'draft');
  assert.equal((await f.projection.get()).exists,false);
  await assert.rejects(f.transition('sign',1),e=>e.code==='failed-precondition');
  const result=await f.sign();assert.deepEqual(await f.sign(),result);
  const version=(await f.ref.collection('versions').doc('1').get()).data();
  assert.equal(version.snapshot.clinical_version,1);assert.equal(version.snapshot.shared_with_patient,false);
  assert.equal(JSON.stringify(version).includes('PRIVATE SYNTHETIC NOTE'),false);
  assert.equal((await db.doc(`clinics/${f.clinicId}/clinical_encounter_private/encounter/versions/1`).get()).data().body,'PRIVATE SYNTHETIC NOTE');
  assert.equal((await db.doc(`clinics/${f.clinicId}/appointments/queue`).get()).data().status,'completed');
  assert.equal((await f.ref.collection('versions').get()).size,1);
  await assert.rejects(f.call({privateNotes:'changed same operation'}),e=>e.code==='already-exists');
});
test('release is separate, targets the linked patient, and amendments retain the first immutable version',async()=>{
  const f=await fixture();await f.call();
  await assert.rejects(f.transition('release',1,{version:0,recipientId:'patient-login',releaseAcknowledgement:true}),e=>e.code==='failed-precondition');
  await f.sign();
  await assert.rejects(f.transition('release',2,{version:1,recipientId:'other-patient',releaseAcknowledgement:true}),e=>e.code==='failed-precondition');
  const release=await f.transition('release',2,{version:1,recipientId:'patient-login',releaseAcknowledgement:true});
  assert.equal(release.released,true);assert.equal((await f.projection.get()).data().shared_with_patient,true);
  await assert.rejects(f.call({operationId:'overwrite',expectedRevision:3}),e=>e.code==='failed-precondition');
  const first=(await f.ref.collection('versions').doc('1').get()).data();
  await f.transition('amend',3,{reason:'Synthetic correction'});
  assert.equal((await f.projection.get()).data().shared_with_patient,true);
  await f.call({operationId:'save-amendment',expectedRevision:4,record:{...f.input.record,advice:'Corrected synthetic advice'}});
  await f.sign(5);
  assert.deepEqual((await f.ref.collection('versions').doc('1').get()).data(),first);
  assert.equal((await f.projection.get()).data().clinical_version,2);
  assert.equal((await f.projection.get()).data().shared_with_patient,false);
  assert.equal((await f.ref.collection('versions').get()).size,2);
});
test('two editors preserve the winning draft and reject stale revisions and another practitioner',async()=>{
  const f=await fixture();await f.call();
  const results=await Promise.allSettled([f.call({operationId:'editor-a',expectedRevision:1,privateNotes:'A'}),f.call({operationId:'editor-b',expectedRevision:1,privateNotes:'B'})]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(results.find(r=>r.status==='rejected').reason.code,'aborted');
  await assert.rejects(f.run({auth:{uid:f.other},data:{...f.input,operationId:'steal',expectedRevision:2}}),e=>e.code==='permission-denied');
});
test('identity/allergy changes invalidate sign review and a cancelled queue visit is not completed',async()=>{
  const f=await fixture();await f.call();
  await db.doc(`clinics/${f.clinicId}/patients/patient`).update({allergies:['Changed synthetic allergy']});
  await assert.rejects(f.sign(),e=>e.code==='aborted');
  await f.call({operationId:'refresh-review',expectedRevision:1});
  await db.doc(`clinics/${f.clinicId}/appointments/queue`).update({status:'cancelled'});
  await assert.rejects(f.sign(2),e=>e.code==='failed-precondition');
  assert.equal((await f.projection.get()).exists,false);
});
test('revoked access and disabled migration fail before receipt replay; existing legacy prescriptions cannot be claimed',async()=>{
  const f=await fixture();await f.call();
  await db.doc(`users/${f.uid}`).update({status:'suspended'});
  await assert.rejects(f.call(),e=>e.code==='permission-denied');
  await db.doc(`users/${f.uid}`).update({status:'approved'});
  await db.doc(`clinics/${f.clinicId}`).update({clinical_v3:false});
  await assert.rejects(f.call(),e=>e.code==='failed-precondition');
  await db.doc(`clinics/${f.clinicId}`).update({clinical_v3:true});
  await db.doc(`clinics/${f.clinicId}/prescriptions/legacy`).set({patient_id:'patient'});
  await assert.rejects(f.call({encounterId:'legacy',operationId:'claim'}),e=>e.code==='failed-precondition');
});
test('private data cannot be injected into the public record and altered patient links cannot receive a release',async()=>{
  const f=await fixture();
  await assert.rejects(f.call({record:{...f.input.record,private_notes:'secret'}}),e=>e.code==='invalid-argument');
  await f.call();await f.sign();
  await db.doc(`clinics/${f.clinicId}/patients/patient`).update({user_id:'changed-login'});
  await assert.rejects(f.transition('release',2,{version:1,recipientId:'changed-login',releaseAcknowledgement:true}),e=>e.code==='failed-precondition');
  assert.equal((await f.projection.get()).data().shared_with_patient,false);
});

test('signed print identity is frozen and a different practitioner letterhead cannot impersonate the signer',async()=>{
  const f=await fixture();
  await db.doc(`clinics/${f.clinicId}`).update({name:'Synthetic clinic at signing',phone:'0000000000'});
  const print=db.doc(`clinics/${f.clinicId}/settings/prescription_print`);
  await print.set({clinician_name:'Different Doctor',registration:'OTHER-REGISTRATION',qualifications:'Other qualification',show_diagnoses:true});
  await f.call();await f.sign();
  const first=(await f.ref.collection('versions').doc('1').get()).data();
  assert.equal(first.snapshot.clinical_print_context.clinician_name,'Synthetic Doctor');
  assert.equal(first.snapshot.clinical_print_context.registration,'');
  await print.update({clinician_name:'Synthetic Doctor',registration:'SYNTHETIC-REGISTRATION'});
  await db.doc(`clinics/${f.clinicId}`).update({name:'Changed later'});
  await f.transition('amend',2,{reason:'Synthetic reviewed correction'});
  await f.call({operationId:'save-revision',expectedRevision:3});
  await f.sign(4);
  assert.deepEqual((await f.ref.collection('versions').doc('1').get()).data(),first);
  const second=(await f.ref.collection('versions').doc('2').get()).data();
  assert.equal(second.snapshot.clinical_print_context.name,'Changed later');
  assert.equal(second.snapshot.clinical_print_context.registration,'SYNTHETIC-REGISTRATION');
});

test('patient access can be revoked without editing the signed version, including while an amendment is open',async()=>{
  const f=await fixture();await f.call();await f.sign();
  await f.transition('release',2,{version:1,recipientId:'patient-login',releaseAcknowledgement:true});
  const immutable=(await f.ref.collection('versions').doc('1').get()).data();
  await f.transition('amend',3,{reason:'Synthetic correction'});
  await assert.rejects(f.transition('revoke',4,{reason:'Synthetic withdrawal'}),e=>e.code==='failed-precondition');
  const input={reason:'Synthetic withdrawal',revokeAcknowledgement:true};
  const first=await f.transition('revoke',4,input);
  assert.deepEqual(await f.transition('revoke',4,input),first);
  assert.equal((await f.projection.get()).data().shared_with_patient,false);
  assert.equal((await f.ref.get()).data().state,'draft');
  assert.deepEqual((await f.ref.collection('versions').doc('1').get()).data(),immutable);
});

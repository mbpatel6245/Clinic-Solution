const {test,after}=require('node:test');
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getFirestore,Timestamp}=require('firebase-admin/firestore');
const {createClinicalArtifactHandler}=require('../lib/clinical_artifacts.js');
if(!/^(localhost|127\.0\.0\.1):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST??''))throw Error('Local Firestore emulator required');
const app=initializeApp({projectId:'demo-clinic-artifacts'}),db=getFirestore(app);
after(()=>deleteApp(app));
const checked={identityReviewed:true,contentReviewed:true,sourceReviewed:true,finalAcknowledgement:true};
const today=()=>new Intl.DateTimeFormat('sv-SE',{timeZone:'Asia/Kolkata',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
async function fixture(){
  const clinicId=`c-${randomUUID()}`,uid=`d-${randomUUID()}`,patientUser=`p-${randomUUID()}`,other=`d-${randomUUID()}`,base=`clinics/${clinicId}`;
  await Promise.all([
    db.doc(base).set({name:'Synthetic clinic',active:true,timezone:'Asia/Kolkata',clinical_artifacts_v1:true,share_clinical_artifacts_with_patients:true,enabled_modules:['clinical','laboratory','vaccination','patients']}),
    db.doc(`users/${uid}`).set({status:'approved',role:'doctor',display_name:'Synthetic Doctor',clinic_ids:[clinicId]}),
    db.doc(`users/${other}`).set({status:'approved',role:'doctor',display_name:'Other Doctor',clinic_ids:[clinicId]}),
    db.doc(`users/${patientUser}`).set({status:'approved',role:'patient',clinic_ids:[clinicId]}),
    db.doc(`${base}/patients/patient`).set({first_name:'Synthetic',last_name:'Patient',user_id:patientUser,allergies:[],abha_id:'PRIVATE-ABHA'}),
    db.doc(`${base}/clinical_encounters/encounter`).set({author_id:uid,patient_id:'patient',state:'signed',version:1,record:{advice:'Existing synthetic advice\nExisting second instruction',follow_up_date:Timestamp.fromDate(new Date('2099-01-02T00:00:00Z'))}}),
    db.doc(`${base}/treatment_plans/plan`).set({patient_id:'patient',name:'Existing synthetic plan',status:'active',notes:'PRIVATE PLAN NOTE',sittings:[{name:'Recorded sitting',scheduled_at:Timestamp.now(),completed:false,notes:'PRIVATE SITTING NOTE'}]}),
    db.doc(`${base}/vaccinations/vaccine`).set({patient_id:'patient',vaccine:'Recorded synthetic vaccine',dose_number:1,administered_at:Timestamp.fromDate(new Date('2020-01-01T00:00:00Z')),batch_number:'SYNTHETIC BATCH',vaccinator:'Synthetic historical clinician',adverse_reaction:'PRIVATE VACCINE NOTE'}),
  ]);
  const run=createClinicalArtifactHandler(db),order={title:'Synthetic request',tests:['Synthetic test'],planned_date:'2099-01-01',indication:'Synthetic indication'};
  const input={clinicId,artifactId:'order',operationId:'save-order',artifactKind:'labOrder',patientId:'patient',action:'saveDraft',expectedRevision:0,record:order};
  const call=(data={})=>run({auth:{uid},data:{...input,...data}});
  const command=(action,revision,extra={})=>call({action,expectedRevision:revision,operationId:`${action}-${revision}-${extra.artifactId??'order'}`,...extra});
  const issue=(revision=1,extra={})=>command('issue',revision,{...checked,...extra});
  const parent=id=>db.doc(`${base}/clinical_artifacts/${id}`),copy=id=>db.doc(`${base}/clinical_artifact_copies/${id}`);
  return {uid,other,patientUser,clinicId,base,input,order,run,call,command,issue,parent,copy};
}
test('lab order draft, reviewed issue and collection are separate idempotent transitions',async()=>{
  const f=await fixture();await f.call();assert.equal((await f.copy('order').get()).exists,false);
  await assert.rejects(f.command('issue',1),e=>e.code==='failed-precondition');
  const first=await f.issue();assert.deepEqual(await f.issue(),first);
  assert.equal((await f.parent('order').get()).data().order_status,'ordered');
  assert.equal((await f.copy('order').get()).data().shared,false);
  await assert.rejects(f.command('collect',2,{collectedAt:new Date().toISOString()}),e=>e.code==='failed-precondition');
  await f.command('collect',2,{collectionReviewed:true,collectedAt:new Date().toISOString()});
  assert.equal((await f.parent('order').get()).data().order_status,'collected');
  assert.equal((await f.parent('order').collection('versions').get()).size,1);
  assert.equal((await db.collection(`${f.base}/laboratory`).get()).size,0);
});
test('concurrent matching pending orders issue exactly once and cancellation permits a reviewed replacement',async()=>{
  const f=await fixture();await f.call();
  await f.call({artifactId:'duplicate',operationId:'save-duplicate',record:{...f.order,tests:[' synthetic TEST ']}});
  const results=await Promise.allSettled([f.issue(),f.issue(1,{artifactId:'duplicate'})]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  const failure=results.find(r=>r.status==='rejected').reason;
  assert.equal(failure.code,'already-exists');assert.ok(failure.details.existingId);
  const winner=failure.details.existingId,loser=winner==='order'?'duplicate':'order';
  await f.command('cancel',2,{artifactId:winner,reason:'Synthetic cancellation'});
  await f.issue(1,{artifactId:loser});
  assert.equal((await f.parent(winner).get()).data().state,'cancelled');
  assert.equal((await f.parent(loser).get()).data().order_status,'ordered');
});
test('care copies contain only selected existing advice and whitelisted source records, with a separate patient release',async()=>{
  const f=await fixture(),record={title:'Existing care copy',instruction_indices:[0],source_plan_id:'plan',vaccination_ids:['vaccine'],verification_note:'PRIVATE SOURCE VERIFICATION'};
  await f.call({artifactId:'care',artifactKind:'carePlan',encounterId:'encounter',operationId:'save-care',record});
  await f.issue(1,{artifactId:'care',artifactKind:'carePlan'});
  const published=(await f.copy('care').get()).data();
  assert.equal(published.shared,false);assert.deepEqual(published.record.instructions,['Existing synthetic advice']);
  assert.equal(published.record.vaccinations.length,1);
  assert.equal(JSON.stringify(published).includes('PRIVATE'),false);
  await assert.rejects(f.command('release',2,{artifactId:'care',artifactKind:'carePlan',version:1,recipientId:'wrong',releaseAcknowledgement:true}),e=>e.code==='failed-precondition');
  await f.command('release',2,{artifactId:'care',artifactKind:'carePlan',version:1,recipientId:f.patientUser,releaseAcknowledgement:true});
  assert.equal((await f.copy('care').get()).data().shared,true);
  await db.doc(`${f.base}/patients/patient`).delete();
  await f.command('revoke',3,{artifactId:'care',artifactKind:'carePlan',revokeAcknowledgement:true,reason:'Synthetic access withdrawal'});
  assert.equal((await f.copy('care').get()).data().shared,false);
});
test('care release fails on changed sources, unrelated patient records, and an unsigned source consultation',async()=>{
  const f=await fixture(),record={title:'Existing care copy',instruction_indices:[0],vaccination_ids:[]};
  await f.call({artifactId:'care',artifactKind:'carePlan',encounterId:'encounter',operationId:'save-care',record});
  await db.doc(`${f.base}/clinical_encounters/encounter`).update({'record.advice':'Changed existing advice'});
  await assert.rejects(f.issue(1,{artifactId:'care',artifactKind:'carePlan'}),e=>e.code==='aborted');
  await db.doc(`${f.base}/clinical_encounters/encounter`).update({state:'draft'});
  await f.call({artifactId:'care',artifactKind:'carePlan',encounterId:'encounter',operationId:'refresh-care',expectedRevision:1,record});
  await assert.rejects(f.issue(2,{artifactId:'care',artifactKind:'carePlan'}),e=>e.code==='failed-precondition');
  await db.doc(`${f.base}/vaccinations/vaccine`).update({patient_id:'other-patient'});
  await assert.rejects(f.call({artifactId:'another',artifactKind:'carePlan',encounterId:'encounter',operationId:'bad-source',record:{...record,vaccination_ids:['vaccine'],verification_note:'Source checked'}}),e=>e.code==='permission-denied');
});
test('reviewed results require collection, distinguish text values, and supersede only their own prior numeric projections',async()=>{
  const f=await fixture();await f.call();await f.issue();
  const record={title:'Synthetic report',order_id:'order',reported_date:today(),source_reference:'SYNTHETIC REPORT',review:'Synthetic reviewed result',observations:[{key:'numeric',analyte:'Synthetic analyte',value:3,unit:'u',lower:1,upper:2},{key:'qualitative',analyte:'Synthetic qualitative',value:null,text_result:'Synthetic text',unit:''}]};
  const save=revision=>f.call({artifactId:'result',artifactKind:'labResult',operationId:`save-result-${revision}`,expectedRevision:revision,record});
  await save(0);
  await assert.rejects(f.issue(1,{artifactId:'result',artifactKind:'labResult'}),e=>e.code==='failed-precondition');
  await f.command('collect',2,{collectionReviewed:true,collectedAt:new Date().toISOString()});
  await assert.rejects(f.issue(1,{artifactId:'result',artifactKind:'labResult'}),e=>e.code==='aborted');
  await save(1);await f.issue(2,{artifactId:'result',artifactKind:'labResult'});
  const rows=(await db.collection(`${f.base}/laboratory`).get()).docs.map(d=>d.data());
  assert.equal(rows.filter(r=>r.record_type==='observation').length,1);
  assert.equal(rows.find(r=>r.record_type==='text_observation').value,null);
  assert.equal((await f.parent('order').get()).data().order_status,'collected');
  assert.equal((await f.parent('order').get()).data().has_report,true);
  const original=(await f.parent('result').collection('versions').doc('1').get()).data();
  await f.command('amend',3,{artifactId:'result',artifactKind:'labResult',reason:'Synthetic correction'});
  record.observations=[{key:'numeric',analyte:'Synthetic analyte',value:4,unit:'different unit',lower:null,upper:null}];
  await save(4);await f.issue(5,{artifactId:'result',artifactKind:'labResult'});
  assert.deepEqual((await f.parent('result').collection('versions').doc('1').get()).data(),original);
  const all=(await db.collection(`${f.base}/laboratory`).get()).docs.map(d=>d.data());
  assert.equal(all.filter(r=>r.superseded!==true).length,1);
  assert.equal(all.find(r=>r.superseded!==true).unit,'different unit');
});
test('stale drafts, other practitioners, disabled migration and disabled laboratory module fail closed',async()=>{
  const f=await fixture();await f.call();
  await assert.rejects(f.call({operationId:'stale'}),e=>e.code==='aborted');
  await assert.rejects(f.run({auth:{uid:f.other},data:{...f.input,operationId:'steal',expectedRevision:1}}),e=>e.code==='permission-denied');
  await db.doc(`users/${f.uid}`).update({role:'receptionist'});
  await assert.rejects(f.issue(),e=>e.code==='permission-denied');
  await db.doc(`users/${f.uid}`).update({role:'doctor'});
  await db.doc(f.base).update({clinical_artifacts_v1:false});
  await assert.rejects(f.issue(),e=>e.code==='failed-precondition');
  await db.doc(f.base).update({clinical_artifacts_v1:true,enabled_modules:['clinical']});
  await assert.rejects(f.issue(),e=>e.code==='permission-denied');
});

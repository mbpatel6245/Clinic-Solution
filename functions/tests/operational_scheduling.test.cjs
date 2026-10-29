const {test,after}=require('node:test');
const assert=require('node:assert/strict');
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getFirestore,Timestamp}=require('firebase-admin/firestore');
const {createOperationalHandler}=require('../lib/operational_scheduling.js');
if(!/^(localhost|127\.0\.0\.1):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST??''))throw Error('Local Firestore emulator required');
const app=initializeApp({projectId:'demo-clinic-operations'}),db=getFirestore(app);
after(()=>deleteApp(app));
const runId=require('node:crypto').randomUUID();
let sequence=0;
async function setup(){
  const clinicId=`clinic-${runId}-${++sequence}`,uid=`staff-${runId}-${sequence}`,doctorId=`doctor-${runId}-${sequence}`;
  await Promise.all([
    db.doc(`clinics/${clinicId}`).set({active:true,operational_v2:true,timezone:'Asia/Kolkata',opening_time:'09:00',closing_time:'18:00',working_days:[1,2,3,4,5,6],enabled_modules:['appointments','patients']}),
    db.doc(`users/${uid}`).set({status:'approved',role:'receptionist',clinic_ids:[clinicId]}),
    db.doc(`users/${doctorId}`).set({status:'approved',role:'doctor',display_name:'Synthetic Doctor',clinic_ids:[clinicId]}),
    db.doc(`clinics/${clinicId}/patients/patient`).set({first_name:'Synthetic',last_name:'Patient',phone:'+919000000123'}),
  ]);
  const run=createOperationalHandler(db,()=>new Date('2026-11-01T00:00:00Z'));
  const input={clinicId,doctorId,kind:'book',operationId:'booking',patientId:'patient',start:'2026-11-02T03:30:00Z',duration:20,reason:'Synthetic review'};
  return {clinicId,uid,doctorId,input,run,call:data=>run({auth:{uid},data:{...input,...data}})};
}
test('racing overlapping bookings accept exactly one complete interval',async()=>{
  const f=await setup();
  const results=await Promise.allSettled([f.call({}),f.call({operationId:'racer',start:'2026-11-02T03:40:00Z'})]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal((await db.collection(`clinics/${f.clinicId}/appointments`).get()).size,1);
});
test('lost acknowledgement replay keeps one appointment and rejects changed ID reuse',async()=>{
  const f=await setup(),first=await f.call({});
  assert.deepEqual(await f.call({}),first);
  await assert.rejects(f.call({duration:30}),e=>e.code==='already-exists');
  await f.call({operationId:'adjacent',start:'2026-11-02T03:50:00Z'});
  assert.equal((await db.collection(`clinics/${f.clinicId}/appointments`).get()).size,2);
});

test('arrival requires separate acknowledgements and repeats without duplicate audit entries',async()=>{
  const f=await setup();await f.call({});
  const run=createOperationalHandler(db,()=>new Date('2026-11-02T03:00:00Z'));
  const data={...f.input,kind:'checkIn',operationId:'arrival',appointmentId:'booking',identityChecked:true,arrivalConsent:false};
  await assert.rejects(run({auth:{uid:f.uid},data}),e=>e.code==='failed-precondition');
  const ref=db.doc(`clinics/${f.clinicId}/appointments/booking`);
  assert.equal((await ref.get()).data().status,'booked');
  data.arrivalConsent=true;
  const first=await run({auth:{uid:f.uid},data});
  const arrived=(await ref.get()).data();
  assert.equal(arrived.status,'confirmed');assert.equal(arrived.identity_checked,true);
  assert.equal(arrived.arrival_by,f.uid);assert.ok(arrived.arrival_at);
  const count=(await db.collection(`clinics/${f.clinicId}/audit_logs`).get()).size;
  assert.deepEqual(await run({auth:{uid:f.uid},data}),first);
  assert.equal((await db.collection(`clinics/${f.clinicId}/audit_logs`).get()).size,count);
});
test('availability edits cannot invalidate any part of a booked visit',async()=>{
  const f=await setup();await f.call({});
  await assert.rejects(f.run({auth:{uid:f.doctorId},data:{...f.input,kind:'availability',operationId:'break-edit',sessions:[[550,1080]]}}),e=>e.code==='failed-precondition');
  assert.equal((await db.collection(`clinics/${f.clinicId}/practitioner_availability`).get()).size,0);
});
test('legacy unassigned intervals block reservations; closed and short sessions reject',async()=>{
  const f=await setup();
  await db.doc(`clinics/${f.clinicId}/appointments/legacy`).set({scheduled_at:Timestamp.fromDate(new Date('2026-11-02T03:40:00Z')),status:'booked'});
  await assert.rejects(f.call({}),e=>e.code==='already-exists');
  await assert.rejects(f.call({operationId:'closed',start:'2026-11-08T03:30:00Z'}),e=>e.code==='failed-precondition');
  await assert.rejects(f.call({operationId:'late',start:'2026-11-02T12:20:00Z',duration:20}),e=>e.code==='failed-precondition');
});
test('revoked membership and disabled migration fail closed before any write',async()=>{
  const f=await setup();
  await db.doc(`users/${f.uid}`).update({clinic_ids:[]});
  await assert.rejects(f.call({}),e=>e.code==='permission-denied');
  await db.doc(`users/${f.uid}`).update({clinic_ids:[f.clinicId]});
  await db.doc(`clinics/${f.clinicId}`).update({operational_v2:false});
  await assert.rejects(f.call({}),e=>e.code==='failed-precondition');
  assert.equal((await db.collection(`clinics/${f.clinicId}/appointments`).get()).size,0);
});
test('a clock transition cannot move a visit outside its working session',async()=>{
  const f=await setup();
  await db.doc(`clinics/${f.clinicId}`).update({timezone:'America/New_York',opening_time:'01:00',closing_time:'04:00',working_days:[7]});
  await assert.rejects(f.call({start:'2026-11-01T05:50:00Z'}),e=>e.code==='failed-precondition');
});

const {test,before}=require('node:test');const assert=require('node:assert/strict');
const host=process.env.FIRESTORE_EMULATOR_HOST;if(!host||!/^(localhost|127\.0\.0\.1):\d+$/.test(host))throw new Error('Run only against a local Firestore emulator');
const project='demo-clinic-templates',base=`http://${host}/v1/projects/${project}/databases/(default)/documents`;
const name=path=>`projects/${project}/databases/(default)/documents/${path}`;
function token(uid){const e=v=>Buffer.from(JSON.stringify(v)).toString('base64url'),now=Math.floor(Date.now()/1000);return `${e({alg:'none',typ:'JWT'})}.${e({aud:project,iss:`https://securetoken.google.com/${project}`,sub:uid,user_id:uid,iat:now,exp:now+3600,firebase:{sign_in_provider:'custom',identities:{}}})}.`}
function value(v){if(Array.isArray(v))return {arrayValue:{values:v.map(value)}};if(typeof v==='boolean')return {booleanValue:v};if(v&&typeof v==='object')return {mapValue:{fields:fields(v)}};return {stringValue:String(v)}}
const fields=o=>Object.fromEntries(Object.entries(o).map(([k,v])=>[k,value(v)]));
async function commit(writes,auth){return fetch(base+':commit',{method:'POST',headers:{'Content-Type':'application/json',...(auth?{Authorization:'Bearer '+auth}:{})},body:JSON.stringify({writes})})}
async function group(collection,auth){return fetch(base+':runQuery',{method:'POST',headers:{'Content-Type':'application/json',...(auth?{Authorization:'Bearer '+auth}:{})},body:JSON.stringify({structuredQuery:{from:[{collectionId:collection,allDescendants:true}]}})})}
before(async()=>{const records={
 'users/owner':{role:'platform_owner',status:'approved'},
 'users/admin':{role:'clinic_admin',status:'approved',clinic_ids:['a'],clinic_roles:{a:'clinic_admin'}},
 'users/patient':{role:'patient',status:'approved'},
 'clinics/a':{name:'Test clinic',active:true},'clinics/b':{name:'Second clinic',active:true},
 'clinics/a/patients/a1':{name:'A'},'clinics/b/patients/b1':{name:'B'},
 'patients/legacy':{name:'Legacy'},'clinics/a/audit_logs/log1':{action:'test'},'platform_settings/notifications':{primary_provider:'msg91'}
 };const r=await commit(Object.entries(records).map(([path,data])=>({update:{name:name(path),fields:fields(data)}})),'owner');assert.equal(r.status,200,await r.text())});
test('owner can query supported modules across all clinics',async()=>{const r=await group('patients',token('owner'));assert.equal(r.status,200,await r.text())});
test('clinic admins, patients and anonymous callers cannot query all-clinic modules',async()=>{for(const auth of [token('admin'),token('patient'),'']){const r=await group('patients',auth);assert.equal(r.status,403,await r.text())}});
test('collection-group permission does not expose protected collections',async()=>{for(const collection of ['notification_outbox','audit_logs','users']){const r=await group(collection,token('owner'));assert.equal(r.status,403,await r.text())}});
test('owner can delete direct clinic module records across clinics',async()=>{const r=await commit([{delete:name('clinics/a/patients/a1')},{delete:name('clinics/b/patients/b1')}],token('owner'));assert.equal(r.status,200,await r.text())});
test('legacy records, audit logs, settings and the current owner cannot be deleted',async()=>{for(const path of ['patients/legacy','clinics/a/audit_logs/log1','platform_settings/notifications','users/owner']){const r=await commit([{delete:name(path)}],token('owner'));assert.equal(r.status,403,await r.text())}});
test('clinic admin cannot delete another clinic record',async()=>{const r=await commit([{delete:name('clinics/b/patients/admin-forbidden')}],token('admin'));assert.equal(r.status,403,await r.text())});

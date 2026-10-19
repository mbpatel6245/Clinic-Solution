import {test} from "node:test";
import assert from "node:assert/strict";
import {createClinicalAiHandler, parseAiInput, validateAiDraft} from "./clinical_ai.js";

const input = {clinicId:"demo",task:"lab_text",text:"Glucose 95 mg/dL (70-100)"} as const;
test("AI is disabled before quota or provider access and requires authentication",async()=>{
  let calls=0;
  const run=createClinicalAiHandler({enabled:()=>false,authorize:async()=>{calls++;return true;},reserve:async()=>{calls++;},generate:async()=>{calls++;return {};}});
  await assert.rejects(run(undefined,input),{code:"unauthenticated"});
  await assert.rejects(run("doctor",input),{code:"failed-precondition"});
  assert.equal(calls,0);
});
test("unauthorized clinic and exhausted quota never invoke the model",async()=>{
  let calls=0;
  const deps={enabled:()=>true,authorize:async()=>false,reserve:async()=>{},generate:async()=>{calls++;return {};}};
  await assert.rejects(createClinicalAiHandler(deps)("staff",input),{code:"permission-denied"});
  await assert.rejects(createClinicalAiHandler({...deps,authorize:async()=>true,reserve:async()=>{throw new Error("quota");}})("doctor",input),/quota/);
  assert.equal(calls,0);
});
test("AI validates task, path, text size and translation language",()=>{
  for(const invalid of [{...input,clinicId:"../clinic"},{...input,text:"x".repeat(20001)},{...input,task:"diagnose"},{...input,task:"translation",language:"invalid"}]) assert.throws(()=>parseAiInput(invalid),{code:"invalid-argument"});
});
test("lab extraction requires source evidence, numeric values and preserves units",()=>{
  const row={analyte:"Glucose",value:95,unit:"mg/dL",evidence:input.text,lower:70,upper:100};
  const draft=validateAiDraft(input,{observations:[row]});
  assert.equal(draft.reviewRequired,true);
  assert.equal(draft.observations?.[0].unit,"mg/dL");
  for(const bad of [{...row,evidence:"invented"},{...row,value:99},{...row,value:Infinity},{...row,lower:200}]) assert.throws(()=>validateAiDraft(input,{observations:[bad]}),{code:"data-loss"});
});
test("translations that change numeric instructions are rejected",()=>{
  const source={...input,task:"translation",language:"hi",text:"Review in 5 days. 1-0-1"} as const;
  assert.throws(()=>validateAiDraft(source,{draft:"Review in 3 days. 1-0-1"}),{code:"data-loss"});
  assert.equal(validateAiDraft(source,{draft:"5 दिन बाद समीक्षा। 1-0-1"}).reviewRequired,true);
});

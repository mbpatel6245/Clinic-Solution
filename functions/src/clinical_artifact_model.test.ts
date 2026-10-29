import {test} from "node:test";
import assert from "node:assert/strict";
import {artifactInput,artifactHash,day,instant} from "./clinical_artifact_model.js";
const order={title:"Synthetic order",tests:["Synthetic test"],planned_date:"2099-01-01",indication:"Synthetic review"};
test("clinical record validation rejects hidden fields, duplicate investigations and invalid calendar dates",()=>{
  assert.throws(()=>artifactInput("labOrder",{...order,private_notes:"must not enter public record"}));
  assert.throws(()=>artifactInput("labOrder",{...order,tests:["TEST A"," test a "]}));
  assert.throws(()=>day("2027-02-29"));assert.equal(day("2028-02-29"),"2028-02-29");
  assert.throws(()=>instant("2026-02-30T12:00:00.000Z"));
  assert.equal(instant("2026-10-29T12:00:00.123456Z"),"2026-10-29T12:00:00.123Z");
});
test("numeric and qualitative results remain distinct and reference ranges never coerce text to zero",()=>{
  const report={title:"Synthetic report",reported_date:"2026-10-29",source_reference:"Synthetic source",review:"Synthetic review",observations:[{key:"one",analyte:"Synthetic",value:null,text_result:"Synthetic qualitative result",unit:"",lower:null,upper:null}]};
  assert.equal(artifactInput("labResult",report).observations[0].value,null);
  assert.throws(()=>artifactInput("labResult",{...report,observations:[{...report.observations[0],lower:0}]}));
  assert.throws(()=>artifactInput("labResult",{...report,observations:[{...report.observations[0],value:1}]}));
  assert.throws(()=>artifactInput("labResult",{...report,observations:[{key:"one",analyte:"Synthetic",value:NaN,unit:"u"}]}));
});
test("care copies require explicit vaccination source verification and deterministic request hashes",()=>{
  assert.throws(()=>artifactInput("carePlan",{title:"Synthetic care",instruction_indices:[0],vaccination_ids:["vaccine"],verification_note:""}));
  assert.throws(()=>artifactInput("carePlan",{title:"Synthetic care",instruction_indices:[0,0]}));
  assert.equal(artifactHash({a:1,b:{c:2}}),artifactHash({b:{c:2},a:1}));
});

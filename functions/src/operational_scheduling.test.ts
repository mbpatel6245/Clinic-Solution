import {test} from "node:test";
import assert from "node:assert/strict";
import {localParts,overlaps} from "./operational_scheduling.js";
test("interval checks cover partial containment, adjacency and clinic timezone",()=>{
  assert.equal(overlaps(10,30,20,40),true);
  assert.equal(overlaps(10,50,20,30),true);
  assert.equal(overlaps(10,20,20,30),false);
  assert.deepEqual(localParts(new Date("2026-11-02T03:30:00Z"),"Asia/Kolkata"),{day:"2026-11-02",minute:540,weekday:1});
});

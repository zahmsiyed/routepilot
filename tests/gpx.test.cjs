const {test}=require('node:test');
const assert=require('node:assert/strict');
const gpx=require('../routepilot/static/gpx.js');
test('pace and duration produce expected metric and imperial speeds',()=>{
 assert.equal(gpx.paceToSpeed('6:00','metric'),10);
 assert.equal(gpx.paceToSpeed('6:00','imperial'),16.09344);
 assert.equal(gpx.speedToPace(10,'metric'),'6:00');
 assert.equal(gpx.speedToPace(16.09344,'imperial'),'6:00');
 assert.equal(gpx.durationToSpeed('30',5000),10);
 for (const units of ['metric','imperial']) for (const speed of [.1,250]) {
  const converted=gpx.paceToSpeed(gpx.speedToPace(speed,units),units);
  assert.ok(converted>=.1&&converted<=250);
 }
});
test('invalid and extreme timing cannot create an activity',()=>{
 for(const pace of ['6:60','0:00','-1:30','6','abc','1:1','9999:59']) assert.throws(()=>gpx.paceToSpeed(pace,'metric'));
 for(const value of ['',0,-1,Infinity,'bad']) assert.throws(()=>gpx.durationToSpeed(value,5000));
 assert.throws(()=>gpx.durationToSpeed('30',0));
});
test('local start dates round-trip with an explicit UTC export offset',()=>{
 const local='2026-09-27T08:30:12';
 assert.equal(gpx.localTime(new Date(gpx.startTime(local))),local);
 assert.ok(gpx.startTime(local).endsWith('Z'));
 for(const value of ['2026-02-30T12:00','1969-12-31T12:00','2026-09-27','bad','2026-09-27T25:00']) assert.throws(()=>gpx.startTime(value));
});
test('download names preserve useful text without paths or control characters',()=>{
 assert.equal(gpx.filename('../../My run <test>'),'My-run-test.gpx');
 assert.equal(gpx.filename(''), 'routepilot.gpx');
 assert.equal(gpx.filename('Parc été'),'Parc-été.gpx');
 assert.ok(gpx.filename('x'.repeat(200)).length<=84);
});

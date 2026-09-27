const {test} = require('node:test');
const assert = require('node:assert/strict');
const RoutePlanner = require('../routepilot/static/planner.js');
const A = [37.77, -122.49], B = [37.78, -122.48], C = [37.79, -122.47];
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(check) {
  for (let i = 0; i < 100; i++) { if (check()) return; await sleep(5); }
  throw new Error('Timed out waiting for planner');
}
function deferred() { let resolve, reject; const promise = new Promise((yes, no) => {resolve = yes; reject = no;}); return {promise, resolve, reject}; }
const ok = (mode, points) => ({profile: mode === 'running' ? 'foot' : 'car', points});

test('stationary returns one coordinate without calling a routing service', async () => {
  let requests = 0;
  const planner = new RoutePlanner(async () => { requests++; }, () => {}, 0);
  planner.update([A, B], 'stationary');
  assert.equal(planner.state.status, 'ready'); assert.deepEqual(planner.state.points, [A]);
  await sleep(10); assert.equal(requests, 0);
  planner.update([], 'stationary'); assert.equal(planner.state.status, 'empty');
});

test('running and driving automatically request their respective routing profiles', async () => {
  const calls = [];
  const planner = new RoutePlanner(async data => { calls.push(data); return ok(data.mode, [A, C, B]); }, () => {}, 0);
  planner.update([A, B], 'running');
  assert.equal(planner.state.status, 'routing'); assert.deepEqual(planner.state.points, []);
  await until(() => planner.state.status === 'ready');
  assert.equal(calls[0].mode, 'running'); assert.deepEqual(planner.state.points, [A, C, B]);
  planner.update([A, B], 'driving');
  assert.equal(planner.state.status, 'routing'); assert.deepEqual(planner.state.points, []);
  await until(() => planner.state.status === 'ready'); assert.equal(calls[1].mode, 'driving');
});

test('a late pedestrian response cannot replace a newer driving route', async () => {
  const jobs = [], published = [];
  const planner = new RoutePlanner(data => {const job = deferred(); jobs.push({data, ...job}); return job.promise;}, state => published.push(state), 0);
  planner.update([A, B], 'running'); await until(() => jobs.length === 1);
  planner.update([A, C], 'driving');
  jobs[0].resolve(ok('running', [A, B]));
  await until(() => jobs.length === 2);
  assert.equal(planner.state.status, 'routing'); assert.equal(published.filter(s => s.status === 'ready').length, 0);
  jobs[1].resolve(ok('driving', [A, C])); await until(() => planner.state.status === 'ready');
  assert.deepEqual(planner.state.points, [A, C]);
});

test('rapid checkpoint edits coalesce while a request is in flight', async () => {
  const jobs = [];
  const planner = new RoutePlanner(data => {const job = deferred(); jobs.push({data, ...job}); return job.promise;}, () => {}, 0);
  planner.update([A, B], 'running'); await until(() => jobs.length === 1);
  planner.update([A, B, C], 'running'); planner.update([A, C], 'running');
  jobs[0].reject(new Error('Old request failed'));
  await until(() => jobs.length === 2);
  assert.deepEqual(jobs[1].data.points, [A, C]); assert.equal(planner.state.status, 'routing');
  jobs[1].resolve(ok('running', [A, C])); await until(() => planner.state.status === 'ready');
  assert.equal(jobs.length, 2);
});

test('routing errors and wrong profiles never fall back to a straight-line route', async () => {
  const planner = new RoutePlanner(async () => { throw new Error('Offline'); }, () => {}, 0);
  planner.update([A, B], 'driving'); await until(() => planner.state.status === 'error');
  assert.deepEqual(planner.state.points, []);
  planner.request = async () => ({profile: 'foot', points: [A, B]});
  planner.update([A, B], 'driving'); await until(() => planner.state.status === 'error');
  assert.deepEqual(planner.state.points, []);
});

test('removing a checkpoint to leave one point invalidates an in-flight route', async () => {
  const job = deferred();
  const planner = new RoutePlanner(() => job.promise, () => {}, 0);
  planner.update([A, B], 'running'); await until(() => planner.inFlight);
  planner.update([A], 'running'); job.resolve(ok('running', [A, B]));
  await until(() => !planner.inFlight);
  assert.equal(planner.state.status, 'empty'); assert.deepEqual(planner.state.points, []);
});

test('loop routing includes the return leg and does not duplicate an existing closed route', async () => {
  const calls = [];
  const planner = new RoutePlanner(async data => {calls.push(data); return ok(data.mode, data.points);}, () => {}, 0);
  planner.update([A, B], 'driving', true); await until(() => planner.state.status === 'ready');
  assert.deepEqual(calls[0].points, [A, B, A]);
  planner.update([A, B, A], 'driving', true); await until(() => calls.length === 2);
  assert.deepEqual(calls[1].points, [A, B, A]);
});

test('null, degenerate, and oversized route responses cannot become playable',async()=>{
  for(const result of [null,ok('running',[A,A]),ok('running',Array.from({length:30001},()=>A))]) {
    const planner=new RoutePlanner(async()=>result,()=>{},0);
    planner.update([A,B],'running');await until(()=>planner.state.status==='error');
    assert.deepEqual(planner.state.points,[]);
  }
});
test('too many checkpoints are rejected without issuing a request',async()=>{
  let called=false;
  const planner=new RoutePlanner(async()=>{called=true;},()=>{},0);
  planner.update(Array.from({length:25},()=>A),'running');
  assert.equal(planner.state.status,'error');await sleep(10);assert.equal(called,false);
});
test('a caller mutating a returned array cannot silently change a ready route',async()=>{
  const points=[A.slice(),B.slice()];
  const planner=new RoutePlanner(async()=>ok('running',points),()=>{},0);
  planner.update([A,B],'running');await until(()=>planner.state.status==='ready');
  points[0][0]=0;assert.deepEqual(planner.state.points[0],A);
});

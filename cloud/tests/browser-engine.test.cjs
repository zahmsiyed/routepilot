const {test}=require('node:test');
const assert=require('node:assert/strict');
const {BrowserEngine,PreviewRoute,distance}=require('../browser-engine.js');
const route={mode:'running',points:[[0,0],[0,.01]],speed:36,loop:false};
test('running advances in meters, pause holds, speed changes and stop resets',()=>{
 const e=new BrowserEngine(); e.command('start',route); e.advance(1);
 assert.equal(e.snapshot().meters,10);
 e.command('pause',{paused:true}); e.advance(2); assert.equal(e.snapshot().meters,10);
 e.command('motion',{speed:72}); e.command('pause',{paused:false}); e.advance(1);
 assert.equal(e.snapshot().meters,30);
 e.command('restore'); assert.equal(e.snapshot().active,false); assert.equal(e.snapshot().position,null);
});
test('stationary, route completion, and repeated loops keep finite positions',()=>{
 const e=new BrowserEngine(); e.command('start',{mode:'stationary',points:[[10,20]],speed:10}); e.advance(2);
 assert.deepEqual(e.snapshot().position,[10,20]); assert.equal(e.snapshot().elapsed,2); assert.equal(e.snapshot().current_speed,0);
 e.command('restore'); e.command('start',{...route,points:[[0,0],[0,.00001]]}); e.advance(2);
 assert.equal(e.snapshot().phase,'completed'); assert.equal(e.snapshot().progress,1); assert.deepEqual(e.snapshot().position,[0,.00001]);
 e.command('restore'); e.command('start',{...route,points:[[0,0],[0,.00001]],loop:true}); e.advance(2);
 assert.ok(e.snapshot().laps>1); assert.ok(e.snapshot().progress<1); assert.ok(e.snapshot().position.every(Number.isFinite));
});
test('preview sessions are isolated and stale commands cannot alter a new session',()=>{
 const a=new BrowserEngine(), b=new BrowserEngine(); a.command('start',route);
 assert.equal(b.snapshot().active,false); const first=a.snapshot().session_id;
 a.command('restore'); a.command('start',route);
 assert.throws(()=>a.command('restore',{session_id:first})); assert.equal(a.snapshot().active,true);
 const result=a.snapshot(true); result.points[0][0]=99; assert.equal(a.snapshot(true).points[0][0],0);
});
test('invalid input is rejected atomically and stalled timers cannot jump far',()=>{
 const e=new BrowserEngine();
 for (const data of [{...route,speed:NaN},{...route,points:[[91,0],[0,0]]},{...route,loop:'yes'},{...route,checkpoints:[[Infinity,0]]},{...route,mode:'flying'}]) {
  assert.throws(()=>e.command('start',data)); assert.equal(e.snapshot().active,false);
 }
 e.command('start',route); assert.throws(()=>e.command('motion',{speed:40,lateral_variation:3})); assert.equal(e.snapshot().speed,36);
 e.advance(10000); assert.equal(e.snapshot().meters,20); assert.equal(e.snapshot().elapsed,2);
});
test('geodesic interpolation crosses the dateline and rejects antipodes',()=>{
 const r=new PreviewRoute([[10,179.9],[10,-179.9]]); const middle=r.at(r.total/2);
 assert.ok(Math.abs(Math.abs(middle[1])-180)<1e-8); assert.ok(r.total<23000);
 assert.throws(()=>new PreviewRoute([[0,0],[0,180]]));
 const p=new PreviewRoute([[90,0],[89.9,0]]); assert.ok(p.lateral(p.total/2,2)[0].every(Number.isFinite));
});
test('speed and lateral variation stay bounded and drift fades at vertices',()=>{
 let seed=42; const rand=()=>{seed=(1664525*seed+1013904223)>>>0;return seed/2**32;};
 const e=new BrowserEngine(rand); e.command('start',{...route,points:[[0,0],[0,1]],speed_variation:5,lateral_variation:2});
 for(let i=0;i<2000;i++) { e.advance(.25); const s=e.snapshot(); assert.ok(s.current_speed>=31&&s.current_speed<=41); assert.ok(Math.abs(s.lateral_offset)<=2); assert.ok(distance(s.position,e.route.at(s.meters))<=2.000001); }
 const r=new PreviewRoute([[0,0],[0,.001],[.001,.001]]); assert.equal(r.lateral(r.cumulative[1],2)[1],0);
 assert.equal(r.lateral(0,2)[1],0); assert.equal(r.lateral(r.total,2)[1],0);
});

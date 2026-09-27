const {test}=require('node:test');
const assert=require('node:assert/strict');
const {RouteClient,RouteState}=require('../routepilot/static/client.js');
const ok=data=>({ok:true,json:async()=>data});
test('hung status requests time out and abort, then a fresh request can succeed',async()=>{
  let signal;
  const client=new RouteClient('token',(_,options)=>{signal=options.signal;return new Promise(()=>{});},{status:10});
  await assert.rejects(client.call('status'),/timed out/);
  assert.equal(signal.aborted,true);
  client.request=async()=>ok({active:false});
  assert.deepEqual(await client.call('status'),{active:false});
});
test('timeout also covers reading the response body',async()=>{
  const client=new RouteClient('token',async()=>({ok:true,json:()=>new Promise(()=>{})}),{status:10});
  await assert.rejects(client.call('status'),/timed out/);
});
test('an uncertain mutating request is never retried',async()=>{
  let calls=0;
  const client=new RouteClient('token',async()=>{calls++;return new Promise(()=>{});},{start:10});
  await assert.rejects(client.call('start',{points:[[1,2]]}),/action may have completed/);
  assert.equal(calls,1);
});
test('expired sessions retain actionable HTTP errors',async()=>{
  const client=new RouteClient('token',async()=>({ok:false,status:403,json:async()=>({error:'Reload RoutePilot.'})}));
  await assert.rejects(client.call('status'),e=>e.status===403&&e.message==='Reload RoutePilot.');
});
test('old poll or control responses cannot overwrite newer session state',()=>{
  const state=new RouteState();
  const snapshot=(revision,active)=>({revision,active,device:'preview'});
  assert.equal(state.accept(snapshot(8,false)),true);
  assert.equal(state.accept(snapshot(7,true)),false);
  assert.equal(state.value.active,false);
  assert.equal(state.accept(snapshot(9,true)),true);
  assert.throws(()=>state.accept({revision:10}),/invalid status/);
  assert.equal(state.value.revision,9);
});

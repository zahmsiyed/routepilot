const {test}=require('node:test');
const assert=require('node:assert/strict');
const PlaceSearch=require('../routepilot/static/search.js');
const place=(name='Park')=>({name,description:'City',point:[37.77,-122.48],bounds:null});
const deferred=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};};
test('search validates input and only requests a submitted query',async()=>{
 let calls=[];const search=new PlaceSearch(async data=>{calls.push(data);return {results:[place()]};},()=>{});
 search.clear();await search.search(' ');assert.equal(calls.length,0);assert.equal(search.state.status,'error');
 await search.search(' Golden  Gate Park ');assert.deepEqual(calls,[{query:'Golden Gate Park'}]);assert.equal(search.state.results[0].name,'Park');
});
test('late responses and failures cannot replace newer search results',async()=>{
 const first=deferred(),second=deferred();let count=0;
 const search=new PlaceSearch(()=>count++?second.promise:first.promise,()=>{});
 const old=search.search('Old park');const latest=search.search('New park');
 second.resolve({results:[place('New park')]});await latest;first.reject(Error('Old failure'));await old;
 assert.equal(search.state.results[0].name,'New park');
});
test('clearing or editing ignores an in-flight response',async()=>{
 const pending=deferred();const search=new PlaceSearch(()=>pending.promise,()=>{});
 const request=search.search('Park');search.clear();pending.resolve({results:[place()]});await request;
 assert.equal(search.state.status,'idle');assert.deepEqual(search.state.results,[]);
});
test('empty and malformed results stay distinct; invalid bounds are discarded',async()=>{
 const search=new PlaceSearch(async()=>({results:[]}),()=>{});await search.search('Park');assert.equal(search.state.status,'ready');
 search.request=async()=>({results:[{...place(),point:[91,2]}]});await search.search('Park');assert.equal(search.state.status,'error');
 search.request=async()=>({results:[{...place(),bounds:[[0,0],[1,1]]}]});await search.search('Park');assert.equal(search.state.results[0].bounds,null);
});

/* Per-tab preview. No device sessions or playback state are stored on Vercel. */
(function(root) {
  'use strict';
  const R = 6371008.8, RAD = Math.PI / 180;
  const clamp = (v, low, high) => Math.max(low, Math.min(high, v));
  const point = p => Array.isArray(p) && p.length === 2 && p.every(Number.isFinite) && Math.abs(p[0]) <= 90 && Math.abs(p[1]) <= 180;
  function number(v, low, high, label) {
    if (typeof v !== 'number' || !Number.isFinite(v) || v < low || v > high) throw Error(`${label} must be between ${low} and ${high}.`);
    return v;
  }
  function distance(a, b) {
    const p = a[0]*RAD, q = b[0]*RAD;
    const h = Math.sin((q-p)/2)**2 + Math.cos(p)*Math.cos(q)*Math.sin((b[1]-a[1])*RAD/2)**2;
    return 2*R*Math.asin(Math.sqrt(clamp(h, 0, 1)));
  }
  function interpolate(a, b, t) {
    if (t <= 0) return [...a];
    if (t >= 1) return [...b];
    const angle = distance(a,b)/R;
    if (angle < 1e-10) return [...a];
    const x = Math.sin((1-t)*angle)/Math.sin(angle), y = Math.sin(t*angle)/Math.sin(angle);
    const [p,l,q,m] = [...a,...b].map(v => v*RAD);
    const vx = x*Math.cos(p)*Math.cos(l) + y*Math.cos(q)*Math.cos(m);
    const vy = x*Math.cos(p)*Math.sin(l) + y*Math.cos(q)*Math.sin(m);
    const vz = x*Math.sin(p) + y*Math.sin(q);
    return [Math.atan2(vz,Math.hypot(vx,vy))/RAD, Math.atan2(vy,vx)/RAD];
  }
  class PreviewRoute {
    constructor(points, loop = false) {
      if (!Array.isArray(points) || !points.length || points.length > 30000 || !points.every(point)) throw Error('Choose 1–30,000 valid route points.');
      if (typeof loop !== 'boolean') throw Error('Loop must be true or false.');
      this.points = [];
      for (const p of points) if (!this.points.length || distance(this.points.at(-1),p) > .001) this.points.push([...p]);
      if (loop && distance(this.points[0],this.points.at(-1)) > .001) {
        if (this.points.length === 30000) throw Error('Leave room for the return point when looping.');
        this.points.push([...this.points[0]]);
      }
      this.cumulative = [0];
      for (let i=1; i<this.points.length; i++) {
        const d = distance(this.points[i-1],this.points[i]);
        if (d/R > Math.PI-1e-6) throw Error('Add an intermediate point between opposite sides of the globe.');
        this.cumulative.push(this.cumulative.at(-1)+d);
      }
      this.total = this.cumulative.at(-1);
    }
    segment(m) {
      let low=0, high=this.cumulative.length-1;
      while (low+1<high) { const mid=(low+high)>>1; if (this.cumulative[mid]<=m) low=mid; else high=mid; }
      return low;
    }
    at(m) {
      if (!this.total || m<=0) return [...this.points[0]];
      if (m>=this.total) return [...this.points.at(-1)];
      const i=this.segment(m);
      return interpolate(this.points[i],this.points[i+1],(m-this.cumulative[i])/(this.cumulative[i+1]-this.cumulative[i]));
    }
    lateral(m, requested) {
      const center=this.at(m);
      if (!requested || m<=0 || m>=this.total) return [center,0];
      const i=this.segment(m), t=clamp(Math.min(m-this.cumulative[i],this.cumulative[i+1]-m)/5,0,1);
      const offset=clamp(requested,-2,2)*t*t*(3-2*t);
      const [lat,lon,q,l]=[...center,...this.points[i+1]].map(v=>v*RAD), dl=l-lon;
      const bearing=Math.atan2(Math.sin(dl)*Math.cos(q),Math.cos(lat)*Math.sin(q)-Math.sin(lat)*Math.cos(q)*Math.cos(dl))+Math.PI/2;
      const a=offset/R, p=Math.asin(clamp(Math.sin(lat)*Math.cos(a)+Math.cos(lat)*Math.sin(a)*Math.cos(bearing),-1,1));
      const n=lon+Math.atan2(Math.sin(bearing)*Math.sin(a)*Math.cos(lat),Math.cos(a)-Math.sin(lat)*Math.sin(p));
      return [[p/RAD,((n/RAD+180)%360+360)%360-180],offset];
    }
  }
  class SmoothNoise {
    constructor(random=Math.random, minimum=6) { this.random=random; this.minimum=minimum; this.value=this.start=this.elapsed=0; this.next(); }
    next() { this.target=this.random()*2-1; this.duration=this.minimum*(1+this.random()); }
    advance(dt) {
      this.elapsed+=dt;
      while (this.elapsed>=this.duration) { this.elapsed-=this.duration; this.start=this.target; this.next(); }
      const t=this.elapsed/this.duration;
      return this.value=this.start+(this.target-this.start)*t*t*(3-2*t);
    }
  }
  class BrowserEngine {
    constructor(random=Math.random) { this.random=random; this.revision=0; this.sequence=0; this.reset(); }
    reset() {
      this.route=null; this.checkpoints=[];
      this.state={session_id:null,phase:'idle',mode:'running',speed:10,current_speed:0,speed_variation:0,lateral_variation:0,lateral_offset:0,meters:0,total:0,elapsed:0,laps:0,position:null,active:false,device:'preview',label:'Browser preview',error:null,loop:false};
      this.revision++;
    }
    snapshot(session=false) {
      const s=this.state;
      return structuredClone({...s,revision:this.revision,progress:s.total?s.meters/s.total:0,remaining:(s.total-s.meters)/(s.speed/3.6),...(session?{points:this.route?.points||[],checkpoints:this.checkpoints}:{})});
    }
    motion(data) {
      return {speed:number(data.speed??this.state.speed,.1,250,'Speed'),speed_variation:number(data.speed_variation??this.state.speed_variation,0,50,'Speed variation'),lateral_variation:number(data.lateral_variation??this.state.lateral_variation,0,2,'Lateral variation')};
    }
    command(path,data={}) {
      const s=this.state;
      if ('session_id' in data && data.session_id!==s.session_id) throw Error('The preview session changed. Try again.');
      if (path==='restore' || path==='preview') this.reset();
      else if (path==='start') {
        if (s.active) throw Error('Stop the current preview first.');
        if (!['stationary','running','driving'].includes(data.mode)) throw Error('Choose a movement mode.');
        const route=new PreviewRoute(data.points,data.loop??false), settings=this.motion(data);
        if (data.mode==='stationary' ? route.points.length!==1 : route.total<.01) throw Error('Choose one stationary location or a route with two distinct points.');
        const checkpoints=data.checkpoints??route.points.filter((_,i)=>i===0||i===route.points.length-1);
        if (!Array.isArray(checkpoints)||!checkpoints.length||checkpoints.length>24||!checkpoints.every(point)) throw Error('Choose up to 24 valid checkpoints.');
        this.route=route; this.checkpoints=structuredClone(checkpoints);
        this.speedNoise=new SmoothNoise(this.random); this.lateralNoise=new SmoothNoise(this.random,8);
        Object.assign(s,settings,{session_id:`preview-${++this.sequence}`,phase:data.mode==='stationary'?'holding':'playing',mode:data.mode,active:true,loop:data.loop??false,total:route.total,position:route.at(0),current_speed:data.mode==='stationary'?0:settings.speed});
      } else if (path==='pause') {
        if (!['playing','paused'].includes(s.phase)||typeof data.paused!=='boolean') throw Error('Only a moving preview can be paused or resumed.');
        s.phase=data.paused?'paused':'playing'; s.current_speed=data.paused?0:clamp(s.speed+s.speed_variation*this.speedNoise.value,.1,250);
      } else if (path==='motion'||path==='speed') {
        const settings=this.motion(data);
        Object.assign(s,settings);
        s.current_speed=s.phase==='playing'?clamp(s.speed+s.speed_variation*this.speedNoise.value,.1,250):0;
      } else throw Error('Use the Mac controller to connect an iPhone.');
      this.revision++; return this.snapshot();
    }
    advance(seconds) {
      const s=this.state, dt=clamp(Number.isFinite(seconds)?seconds:0,0,2);
      if (!dt||!['playing','holding'].includes(s.phase)) return;
      s.elapsed+=dt;
      if (s.phase==='playing') {
        const previous=s.current_speed;
        s.current_speed=clamp(s.speed+s.speed_variation*this.speedNoise.advance(dt),.1,250);
        s.meters+=(previous+s.current_speed)*dt/7.2;
        if (s.meters>=s.total) {
          if (s.loop) { s.laps+=Math.floor(s.meters/s.total); s.meters%=s.total; }
          else { s.meters=s.total; s.phase='completed'; s.current_speed=0; }
        }
        [s.position,s.lateral_offset]=this.route.lateral(s.meters,s.lateral_variation*this.lateralNoise.advance(dt));
      }
      this.revision++;
    }
  }
  if (typeof module!=='undefined'&&module.exports) module.exports={BrowserEngine,PreviewRoute,distance};
  if (root.document) {
    root.ROUTEPILOT_CLOUD=true;
    const BaseClient=root.RouteClient;
    root.RouteClient=class extends BaseClient {
      constructor(...args) {
        super(...args); this.engine=new BrowserEngine(); let last=performance.now();
        setInterval(()=>{const now=performance.now(); if (!document.hidden) this.engine.advance((now-last)/1000); last=now;},250);
        document.addEventListener('visibilitychange',()=>{last=performance.now();});
      }
      async call(path,data,blob=false) {
        if (path==='status'||path==='session') return this.engine.snapshot(path==='session');
        if (['search','route','import','export'].includes(path)) {
          try { return await super.call(path,data,blob); }
          catch(error) { if (error.message.includes('local app')) error.message='Cannot reach the hosted service. Check your internet connection and retry.'; throw error; }
        }
        if (path==='devices') return {devices:[]};
        return this.engine.command(path,data);
      }
    };
  }
})(globalThis);

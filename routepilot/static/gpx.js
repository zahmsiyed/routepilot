(function(root) {
  'use strict';
  const unitMeters = units => units === 'imperial' ? 1609.344 : 1000;
  function validSpeed(speed) {
    if (!Number.isFinite(speed) || speed < .1 || speed > 250) throw Error('Choose a pace or duration equivalent to 0.1–250 km/h.');
    return speed;
  }
  function paceToSpeed(text, units) {
    const match = /^(\d{1,4}):([0-5]\d)$/.exec(String(text).trim());
    if (!match) throw Error('Enter pace as minutes:seconds, for example 6:00.');
    const seconds = Number(match[1])*60+Number(match[2]);
    return validSpeed(unitMeters(units)*3.6/seconds);
  }
  function speedToPace(speed, units) {
    const scale = unitMeters(units)*3.6;
    const seconds = Math.max(Math.ceil(scale/250), Math.min(Math.floor(scale/.1), Math.round(scale/validSpeed(speed))));
    return `${Math.floor(seconds/60)}:${String(seconds%60).padStart(2,'0')}`;
  }
  function durationToSpeed(text, meters) {
    const minutes = Number(text);
    if (!String(text).trim() || !Number.isFinite(minutes) || minutes <= 0 || !(meters > 0)) throw Error('Enter a positive duration in minutes for a moving route.');
    return validSpeed(meters*3.6/(minutes*60));
  }
  function localTime(date) {
    const pad = value => String(value).padStart(2,'0');
    return `${date.getFullYear()}-${pad(date.getMonth()+1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
  }
  function startTime(raw) {
    if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$/.test(raw)) throw Error('Choose a start date and time.');
    const normalized = raw.length === 16 ? raw+':00' : raw, date = new Date(normalized);
    if (!Number.isFinite(date.getTime()) || date.getFullYear()<1970 || localTime(date)!==normalized) throw Error('Choose a valid local date and time, including daylight-saving changes.');
    return date.toISOString();
  }
  function filename(name) { return (String(name).trim().replace(/[^\p{L}\p{N}_-]+/gu,'-').replace(/^-+|-+$/g,'').slice(0,80) || 'routepilot')+'.gpx'; }
  const api={paceToSpeed,speedToPace,durationToSpeed,localTime,startTime,filename};
  root.RouteGPX=api;
  if(typeof module!=='undefined'&&module.exports) module.exports=api;
})(globalThis);

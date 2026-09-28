'use strict';
const $ = id => document.getElementById(id);
const hosted = globalThis.ROUTEPILOT_CLOUD === true;
const token = document.querySelector('meta[name="routepilot-token"]').content;
const client = new RouteClient(token), stateStore = new RouteState();
const validPoint = p => Array.isArray(p) && p.length === 2 && p.every(Number.isFinite) && Math.abs(p[0]) <= 90 && Math.abs(p[1]) <= 180;
const U = RouteUnits;
let draft = {mode: 'running', speed: 10, loop: false, waypoints: [], units: 'metric', speedVariationEnabled: false, speedVariation: 1, lateralEnabled: false, lateralVariation: .75};
let history = [];
let state = {phase: 'idle', active: false, device: 'preview', position: null, progress: 0};
let busy = false, offline = true, polling = false, toastTimer, currentMarker;
let pendingMotion = 0, motionGeneration = 0, networkEpoch = 0, statusError = '', liveSession = null, loadingSession = false, deviceRefresh = 0;
let motionQueue = Promise.resolve(), draggingMarker = false, lastMarkerDrag = -Infinity, addedMarker = -1;
let connectingRequest = false, connectionShown = false, ignoredConnectionAttempt = null;
let gpxDraft = null, gpxSaving = false;
try {
  const saved = JSON.parse(localStorage.getItem('routepilot-draft-v1'));
  if (saved && ['stationary', 'running', 'driving'].includes(saved.mode) && Array.isArray(saved.waypoints)) {
    draft = {...draft, mode: saved.mode, speed: Number(saved.speed), loop: !!saved.loop, waypoints: saved.waypoints.filter(validPoint).slice(0, 24),
      units: saved.units === 'imperial' ? 'imperial' : 'metric', speedVariationEnabled: saved.speedVariationEnabled === true, lateralEnabled: saved.lateralEnabled === true};
    if (Number.isFinite(saved.speedVariation) && saved.speedVariation >= 0 && saved.speedVariation <= 50) draft.speedVariation = saved.speedVariation;
    if (Number.isFinite(saved.lateralVariation) && saved.lateralVariation >= 0 && saved.lateralVariation <= 2) draft.lateralVariation = saved.lateralVariation;
    if (!Number.isFinite(draft.speed) || draft.speed < .1 || draft.speed > 250) draft.speed = 10;
    if (draft.mode === 'stationary') draft.waypoints = draft.waypoints.slice(0, 1);
  }
} catch (_) {}
const map = L.map('map', {zoomControl: false, attributionControl: false, doubleClickZoom: false}).setView([37.7694, -122.4862], 14);
L.control.zoom({position: 'topright'}).addTo(map);
L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {maxZoom: 19, minZoom: 2}).addTo(map).on('tileerror', () => { $('tileError').hidden = false; });
const routeLayer = L.layerGroup().addTo(map);
const markerLayer = L.layerGroup().addTo(map);
const planner = new RoutePlanner(data => api('route', data), () => renderDraft());
const placeSearch = new PlaceSearch(data => api('search', data), () => renderSearch());
let selectedPlace = null, searchMarker = null;
let storageWarning = false;
function saveDraft() {
  try { localStorage.setItem('routepilot-draft-v1', JSON.stringify(draft)); }
  catch (_) { if (!storageWarning) { storageWarning = true; notify('Browser storage is unavailable. Keep this tab open to retain your draft.', true); } }
}
function remember() { history.push(structuredClone({mode:draft.mode, loop:draft.loop, waypoints:draft.waypoints})); if (history.length > 50) history.shift(); }
function edited() { saveDraft(); planner.update(draft.waypoints, draft.mode, draft.loop); }
function undo() { if (locked() || !history.length) return; Object.assign(draft, history.pop()); edited(); }
function notify(message, error = false) {
  clearTimeout(toastTimer); $('toast').textContent = message; $('toast').className = 'toast' + (error ? ' error' : ''); $('toast').hidden = false;
  toastTimer = setTimeout(() => { $('toast').hidden = true; }, error ? 9000 : 4000);
}
async function api(path, data, blob = false) {
  try { return await client.call(path, data, blob); }
  catch (error) {
    if (error.status === 403) { statusError = 'Session expired. Reload the page to reconnect to RoutePilot.'; offline = true; renderStatus(); }
    throw error;
  }
}
function selectedMode() { return state.active ? state.mode : draft.mode; }
function shownCheckpoints() { return state.active ? (liveSession?.checkpoints ?? []) : draft.waypoints; }
function syncMotion() {
  if (!state.active || pendingMotion) return;
  draft.speed = state.speed;
  draft.speedVariationEnabled = state.speed_variation > 0;
  draft.lateralEnabled = state.lateral_variation > 0;
  if (state.speed_variation > 0) draft.speedVariation = state.speed_variation;
  if (state.lateral_variation > 0) draft.lateralVariation = state.lateral_variation;
}
function acceptState(next) {
  if (!stateStore.accept(next)) return false;
  const old = state; state = next;
  offline = false; statusError = '';
  if (old.session_id !== state.session_id || !state.active) liveSession = null;
  syncMotion();
  if (state.active && !liveSession) loadLiveSession();
  return true;
}
async function loadLiveSession() {
  if (loadingSession || !state.active) return;
  loadingSession = true;
  try {
    const session = await api('session');
    if (session.session_id === state.session_id && state.active && Array.isArray(session.points) && session.points.every(validPoint) && Array.isArray(session.checkpoints) && session.checkpoints.every(validPoint)) {
      liveSession = session; renderDraft(); fitRoute();
    }
  } catch (error) { notify('Could not load the active route. ' + error.message, true); }
  finally { loadingSession = false; }
}
async function control(path, data = {}) {
  networkEpoch++;
  const expected = state.session_id ?? null;
  const result = await api(path, {...data, session_id:expected});
  acceptState(result);
}
function isConnecting() { return connectingRequest || !!state.connection?.active; }
function locked() { return busy || isConnecting() || offline || state.active; }
async function action(fn, waitForMotion = true) {
  if (busy || isConnecting()) return;
  busy = true; renderDraft();
  try { if (waitForMotion) await motionQueue; await fn(); } catch (error) { notify(error.message, true); }
  finally { busy = false; await poll(); renderDraft(); }
}
function coords(p) { return p.map(n => n.toFixed(5)).join(', '); }
function routePoints() { return planner.state.status === 'ready' ? planner.state.points : []; }
function meters(a, b) {
  const rad = Math.PI / 180, p = a[0] * rad, q = b[0] * rad;
  const h = Math.sin((q-p)/2)**2 + Math.cos(p)*Math.cos(q)*Math.sin((b[1]-a[1])*rad/2)**2;
  return 12742017.6 * Math.asin(Math.sqrt(Math.max(0, Math.min(1, h))));
}
function length(points) { return points.slice(1).reduce((sum, p, i) => sum + meters(points[i], p), 0); }
function duration(seconds) {
  if (!Number.isFinite(seconds)) return '—';
  const s = Math.max(0, Math.round(seconds));
  return s >= 3600 ? `${Math.floor(s/3600)}:${String(Math.floor(s/60)%60).padStart(2,'0')}:${String(s%60).padStart(2,'0')}` : `${String(Math.floor(s/60)).padStart(2,'0')}:${String(s%60).padStart(2,'0')}`;
}
function addPoint(point) {
  if (locked()) return false;
  if (!validPoint(point)) { notify('Enter a valid latitude and longitude.', true); return false; }
  if (draft.mode !== 'stationary' && draft.waypoints.length >= 24) { notify('Use up to 24 checkpoints.', true); return false; }
  remember();
  if (draft.mode === 'stationary') draft.waypoints = [point];
  else draft.waypoints.push(point);
  addedMarker = draft.waypoints.length - 1;
  edited();
  return true;
}
function removePoint(index) {
  if (locked() || index < 0 || index >= draft.waypoints.length) return;
  remember(); draft.waypoints.splice(index, 1); edited();
}
map.on('click', e => { if (performance.now() - lastMarkerDrag < 300) return; const p = e.latlng.wrap(); addPoint([p.lat, p.lng]); });
function fitRoute() {
  const points = state.active ? (liveSession?.points ?? (state.position ? [state.position] : [])) : routePoints().length ? routePoints() : draft.waypoints;
  if (points.length === 1) map.setView(points[0], 15);
  else if (points.length > 1) map.fitBounds(points, {paddingTopLeft: [35, 75], paddingBottomRight: [35, 35], maxZoom: 16});
}
function drawRoute() {
  routeLayer.clearLayers();
  const points = state.active ? (liveSession?.points ?? []) : routePoints();
  if (points.length > 1) {
    L.polyline(points, {color: '#fff', weight: 8, opacity: .95}).addTo(routeLayer);
    L.polyline(points, {color: '#27714c', weight: 4, opacity: .95}).addTo(routeLayer);
  }
  // Keep the marker DOM alive while a drag is in progress, even if routing finishes.
  if (draggingMarker) return;
  markerLayer.clearLayers();
  const shown = shownCheckpoints();
  shown.forEach((point, index) => {
    const editable = !locked();
    const icon = L.divIcon({className: 'checkpoint-marker' + (editable ? '' : ' locked') + (index === addedMarker ? ' new' : ''), html: `<span class="checkpoint-dot">${index+1}</span>`, iconSize: [34,34], iconAnchor: [17,17]});
    const marker = L.marker(point, {icon, draggable: editable, keyboard: editable, interactive: editable, bubblingMouseEvents: false, title: `Checkpoint ${index+1}${editable ? ' · Drag to move · Click to remove' : ''}`}).addTo(markerLayer);
    marker.getElement().setAttribute('aria-label', `Checkpoint ${index+1}${editable ? ' · Drag to move · Click to remove' : ''}`);
    marker.on('dragstart', () => { draggingMarker = true; marker.closeTooltip(); });
    marker.on('dragend', () => {
      draggingMarker = false; lastMarkerDrag = performance.now();
      if (locked()) return drawRoute();
      const p = marker.getLatLng().wrap();
      remember(); draft.waypoints[index] = [p.lat, p.lng]; edited();
    });
    marker.on('click', event => {
      if (event.originalEvent) L.DomEvent.stopPropagation(event.originalEvent);
      if (performance.now() - lastMarkerDrag < 300) return;
      removePoint(index);
    });
    if (editable) marker.bindTooltip('Drag to move · Click to remove', {className:'checkpoint-tooltip', direction:'top', offset:[0,-18]});
  });
  addedMarker = -1;
}
function renderMotion() {
  const unit = draft.units, speedUnit = U.speedLabel(unit), lateralUnit = U.lateralLabel(unit);
  document.querySelectorAll('[data-unit]').forEach(button => button.setAttribute('aria-pressed', button.dataset.unit === unit));
  $('speedUnit').textContent = $('variationUnit').textContent = speedUnit;
  $('lateralUnit').textContent = lateralUnit;
  $('speedNumber').setAttribute('aria-label', `Speed in ${unit === 'imperial' ? 'miles' : 'kilometers'} per hour`);
  $('speedNumber').min = U.format(U.speedToDisplay(.1, unit));
  $('speedNumber').max = U.format(U.speedToDisplay(250, unit));
  $('speedNumber').step = $('speedRange').step = '.01';
  if (document.activeElement !== $('speedNumber')) $('speedNumber').value = U.format(U.speedToDisplay(draft.speed, unit));
  $('speedRange').min = $('speedNumber').min;
  $('speedRange').max = U.format(U.speedToDisplay(Math.max(selectedMode() === 'driving' ? 160 : 25, draft.speed), unit));
  $('speedRange').value = U.format(U.speedToDisplay(draft.speed, unit));
  $('speedVariationEnabled').checked = draft.speedVariationEnabled;
  $('lateralEnabled').checked = draft.lateralEnabled;
  $('speedVariation').max = U.format(U.speedToDisplay(50, unit));
  $('lateralVariation').max = U.format(U.lateralToDisplay(2, unit));
  $('speedVariation').step = $('lateralVariation').step = '.01';
  if (document.activeElement !== $('speedVariation')) $('speedVariation').value = U.format(U.speedToDisplay(draft.speedVariation, unit));
  if (document.activeElement !== $('lateralVariation')) $('lateralVariation').value = U.format(U.lateralToDisplay(draft.lateralVariation, unit));
  $('lateralVariation').title = `Maximum ${U.format(U.lateralToDisplay(2, unit))} ${lateralUnit}`;
  $('speedBand').hidden = !draft.speedVariationEnabled;
  $('speedBand').textContent = `${U.format(U.speedToDisplay(Math.max(.1, draft.speed - draft.speedVariation), unit))}–${U.format(U.speedToDisplay(Math.min(250, draft.speed + draft.speedVariation), unit))} ${speedUnit}`;
}

function renderDraft() {
  const mode = selectedMode(), stationary = mode === 'stationary';
  const shown = shownCheckpoints();
  document.querySelectorAll('.mode').forEach(button => {
    button.classList.toggle('active', button.dataset.mode === selectedMode());
    button.setAttribute('aria-pressed', button.dataset.mode === selectedMode());
    button.disabled = locked();
  });
  $('modeHint').textContent = stationary ? 'Holds a single location.' : mode === 'running' ? 'Follows pedestrian paths automatically.' : 'Follows driving routes automatically.';
  $('paceSection').hidden = stationary;
  $('pointCount').textContent = shown.length;
  $('routeHint').textContent = 'Click map to add. Drag to move. Click marker to remove.';
  $('mapInstruction').textContent = state.active ? 'Route in progress' : stationary ? 'Click to set a location' : 'Click to add a checkpoint';
  $('undoButton').disabled = locked() || !history.length;
  $('clearButton').hidden = !draft.waypoints.length; $('clearButton').disabled = locked();
  $('waypoints').replaceChildren();
  if (!shown.length) {
    const empty = document.createElement('p'); empty.className = 'empty-route'; empty.textContent = stationary ? 'No location selected.' : 'No checkpoints yet.'; $('waypoints').append(empty);
  }
  shown.forEach((point, index) => {
    const row = document.createElement('div'); row.className = 'waypoint';
    const number = document.createElement('b'); number.textContent = index+1;
    const text = document.createElement('div'), title = document.createElement('strong'), subtitle = document.createElement('small');
    title.textContent = stationary ? 'Location' : `Checkpoint ${index+1}`; subtitle.textContent = coords(point); text.append(title, subtitle);
    const remove = document.createElement('button'); remove.className = 'remove-checkpoint'; remove.textContent = 'Remove'; remove.setAttribute('aria-label', `Remove checkpoint ${index+1}`); remove.disabled = locked(); remove.onclick = () => removePoint(index);
    row.append(number, text, remove); $('waypoints').append(row);
  });
  $('coordinateInput').disabled = locked(); $('coordinateForm').querySelector('button').disabled = locked();
  ['reverseButton', 'importButton', 'demoButton'].forEach(id => { $(id).disabled = locked(); });
  $('reverseButton').disabled = locked() || stationary || draft.waypoints.length < 2;
  $('loopInput').checked = draft.loop; $('loopInput').disabled = locked() || stationary;
  renderMotion(); drawRoute(); renderStatus();
}
function renderStatus() {
  const live = state.active, iphone = state.device === 'iphone', plan = planner.state, connecting = isConnecting();
  $('deviceBadge').textContent = connecting ? 'Connecting to iPhone…' : iphone ? state.label : hosted ? 'Browser preview' : 'Preview only'; $('deviceBadge').classList.toggle('connected', iphone && !state.error && !offline);
  $('connectionButton').textContent = hosted ? 'Use with iPhone' : connecting ? 'View connection progress' : iphone ? state.error ? 'iPhone needs attention' : 'iPhone connected' : 'Connect iPhone'; $('connectionButton').disabled = busy && !connecting;
  const total = live ? state.total : length(routePoints());
  $('distanceStat').textContent = ((live || plan.status === 'ready') ? U.distanceToDisplay(total, draft.units).toFixed(2) : '—') + ' ' + U.distanceLabel(draft.units);
  $('durationStat').textContent = live ? duration(state.elapsed) : plan.status === 'ready' ? duration(total/(draft.speed/3.6)) : '—';
  let message;
  if (offline) message = statusError || 'App disconnected. Reload this page or relaunch RoutePilot.';
  else if (connecting) message = state.connection?.steps?.at(-1)?.label || 'Connecting to iPhone…';
  else if (state.error) message = state.error;
  else if (live) message = ({playing: state.mode === 'driving' ? 'Driving…' : 'Running…', starting: 'Applying the first location…', restoring: 'Restoring real location…', paused: 'Paused at this location.', holding: 'Holding this location.', completed: 'Route finished. Holding the final location.'})[state.phase] || 'Session needs attention.';
  else if (plan.status === 'routing') message = draft.mode === 'running' ? 'Finding a pedestrian route…' : 'Finding a driving route…';
  else if (plan.status === 'error') message = plan.error || 'No route available. Move a checkpoint or retry.';
  else if (plan.status === 'ready') message = draft.mode === 'stationary' ? 'Location ready.' : draft.mode === 'running' ? 'Pedestrian route ready.' : 'Driving route ready.';
  else message = draft.mode === 'stationary' ? 'Choose a location on the map.' : 'Add two checkpoints to begin.';
  $('routeStatus').textContent = message; $('routeStatus').classList.toggle('error', !!state.error || plan.status === 'error' || offline);
  $('retryButton').hidden = live || plan.status !== 'error'; $('retryButton').disabled = busy || offline;
  $('progress').hidden = !live || state.mode === 'stationary'; $('progress').value = state.progress || 0;
  $('startButton').textContent = busy ? 'Working…' : iphone ? draft.mode === 'stationary' ? 'Apply location' : 'Start on iPhone' : 'Start preview';
  $('startButton').disabled = busy || connecting || offline || live || plan.status !== 'ready';
  $('saveButton').disabled = busy || gpxSaving || offline || (live ? !liveSession?.points?.length : plan.status !== 'ready');
  $('pauseButton').hidden = !['playing', 'paused'].includes(state.phase);
  $('pauseButton').textContent = state.phase === 'paused' ? 'Resume' : 'Pause'; $('pauseButton').disabled = busy || offline;
  $('restoreButton').hidden = !live && !iphone; $('restoreButton').textContent = iphone ? 'Restore real location' : 'Stop preview'; $('restoreButton').disabled = busy || offline;
  const motionLocked = busy || connecting || offline || pendingMotion > 0 || (state.active && !['playing','paused'].includes(state.phase));
  $('speedNumber').disabled = motionLocked; $('speedRange').disabled = motionLocked;
  $('speedVariationEnabled').disabled = $('lateralEnabled').disabled = motionLocked;
  $('speedVariation').disabled = motionLocked || !draft.speedVariationEnabled;
  $('lateralVariation').disabled = motionLocked || !draft.lateralEnabled;
  $('liveMotion').hidden = !live || state.mode === 'stationary';
  $('liveMotion').textContent = `Current speed ${U.format(U.speedToDisplay(state.current_speed ?? state.speed ?? 0, draft.units))} ${U.speedLabel(draft.units)}`;
  $('playbackNote').textContent = hosted ? 'Browser preview only. Pauses while this tab is hidden. Use the Mac controller to change iPhone location.' : iphone ? 'Keep USB connected. Restore real location when finished.' : 'Preview only. Connect an iPhone to change its location.';
  if (state.position) {
    if (!currentMarker) currentMarker = L.marker(state.position, {icon: L.divIcon({className:'current-marker', iconSize:[22,22], iconAnchor:[11,11]}), zIndexOffset:1000, interactive:false}).addTo(map);
    else currentMarker.setLatLng(state.position);
  } else if (currentMarker) { map.removeLayer(currentMarker); currentMarker = null; }
  renderConnection();
  renderSearchAvailability();
}
async function poll() {
  if (polling || (busy && !connectingRequest) || pendingMotion) return;
  polling = true;
  const epoch = networkEpoch;
  try {
    const wasOffline = offline, old = state, next = await api('status');
    if (!acceptState(next)) return;
    if (state.error && state.error !== old.error) notify(state.error, true);
    if (wasOffline || old.active !== state.active || old.device !== state.device || old.session_id !== state.session_id || old.phase !== state.phase || old.connection?.active !== state.connection?.active) renderDraft();
    else { renderMotion(); renderStatus(); }
  } catch (error) { if (epoch === networkEpoch) { offline = true; statusError = error.message; renderDraft(); } }
  finally { polling = false; }
}
setInterval(() => { if (!document.hidden) poll(); }, 700);
document.addEventListener('visibilitychange', () => { if (!document.hidden) poll(); });
document.querySelectorAll('.mode').forEach(button => { button.onclick = () => {
  if (locked() || button.dataset.mode === selectedMode()) return;
  if (button.dataset.mode === 'stationary' && draft.waypoints.length > 1) { remember(); draft.waypoints = draft.waypoints.slice(0, 1); }
  draft.mode = button.dataset.mode; draft.speed = draft.mode === 'driving' ? 50 : 10; edited();
}; });
$('coordinateForm').onsubmit = event => {
  event.preventDefault();
  const parts = $('coordinateInput').value.trim().split(/\s*,\s*|\s+/), point = parts.map(Number);
  if (parts.length !== 2 || parts.some(p => !p) || !validPoint(point)) return notify('Enter latitude, longitude — for example 37.7694, -122.4862.', true);
  addPoint(point); map.panTo(point); $('coordinateInput').value = '';
};
$('undoButton').onclick = undo;
document.addEventListener('keydown', event => {
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'z' && !event.shiftKey && !event.target.closest('input, textarea, select, [contenteditable]')) { event.preventDefault(); undo(); }
});
$('clearButton').onclick = () => { if (locked()) return; remember(); draft.waypoints = []; edited(); };
$('reverseButton').onclick = () => { if (locked()) return; remember(); draft.waypoints.reverse(); edited(); };
$('loopInput').onchange = () => { if (locked()) return; remember(); draft.loop = $('loopInput').checked; edited(); };
$('fitButton').onclick = fitRoute;
$('retryButton').onclick = () => planner.update(draft.waypoints, draft.mode, draft.loop);
function motionData() {
  return {speed:draft.speed, speed_variation:draft.speedVariationEnabled ? draft.speedVariation : 0, lateral_variation:draft.lateralEnabled ? draft.lateralVariation : 0};
}
function motionChanged() {
  saveDraft(); renderMotion(); renderStatus();
  if (state.active) {
    networkEpoch++;
    const data = {...motionData(), session_id:state.session_id}, generation = ++motionGeneration;
    pendingMotion++;
    renderStatus();
    motionQueue = motionQueue.then(async () => {
      try {
        if (generation !== motionGeneration) return;
        acceptState(await api('motion', data));
      } catch (error) {
        notify(error.message, true);
      } finally {
        pendingMotion--;
        if (!pendingMotion) {
          syncMotion(); saveDraft(); renderMotion(); renderStatus();
          await poll();
        }
      }
    });
  }
}
function readMotionValue(raw, kind, minimum, maximum) {
  const toDisplay = kind === 'lateral' ? U.lateralToDisplay : U.speedToDisplay;
  const toCanonical = kind === 'lateral' ? U.lateralToCanonical : U.speedToCanonical;
  const value = Number(raw), low = Number(U.format(toDisplay(minimum, draft.units))), high = Number(U.format(toDisplay(maximum, draft.units)));
  if (!String(raw).trim() || !Number.isFinite(value) || value < low || value > high) {
    const label = kind === 'lateral' ? U.lateralLabel(draft.units) : U.speedLabel(draft.units);
    throw new Error(`Choose ${low} to ${high} ${label}.`);
  }
  // Accept rounded display endpoints without changing canonical safety bounds.
  return Math.max(minimum, Math.min(maximum, toCanonical(value, draft.units)));
}
function changeNumber(input, key, kind, minimum, maximum) {
  try { draft[key] = readMotionValue(input.value, kind, minimum, maximum); motionChanged(); }
  catch (error) { notify(error.message, true); }
  const convert = kind === 'lateral' ? U.lateralToDisplay : U.speedToDisplay;
  input.value = U.format(convert(draft[key], draft.units));
}
document.querySelectorAll('[data-unit]').forEach(button => { button.onclick = () => {
  draft.units = button.dataset.unit; saveDraft(); renderMotion(); renderStatus();
}; });
$('speedNumber').onchange = event => changeNumber(event.target, 'speed', 'speed', .1, 250);
$('speedRange').oninput = event => { $('speedNumber').value = event.target.value; };
$('speedRange').onchange = event => { changeNumber(event.target, 'speed', 'speed', .1, 250); $('speedNumber').value = U.format(U.speedToDisplay(draft.speed, draft.units)); };
$('speedVariation').onchange = event => changeNumber(event.target, 'speedVariation', 'speed', 0, 50);
$('lateralVariation').onchange = event => changeNumber(event.target, 'lateralVariation', 'lateral', 0, 2);
$('speedVariationEnabled').onchange = event => { draft.speedVariationEnabled = event.target.checked; motionChanged(); };
$('lateralEnabled').onchange = event => { draft.lateralEnabled = event.target.checked; motionChanged(); };
$('startButton').onclick = () => { if (planner.state.status !== 'ready' || locked()) return; action(async () => { await control('start', {points:routePoints(), checkpoints:draft.waypoints, mode:draft.mode, ...motionData(), loop:draft.mode !== 'stationary' && draft.loop}); }); };
$('pauseButton').onclick = () => action(async () => { await control('pause', {paused:state.phase !== 'paused'}); });
$('restoreButton').onclick = () => { motionGeneration++; action(async () => { await control('restore'); }, false); };
$('saveButton').onclick = () => {
  if (gpxSaving || $('saveButton').disabled) return;
  const points = state.active ? liveSession.points : routePoints();
  gpxDraft = {points:structuredClone(points), mode:selectedMode(), units:draft.units, speed:state.active ? state.speed : draft.speed, loop:state.active ? state.loop : draft.loop, total:length(points)};
  const moving = gpxDraft.mode !== 'stationary' && gpxDraft.total >= .01;
  $('gpxName').value = moving ? `RoutePilot simulated ${gpxDraft.mode === 'running' ? 'run' : 'drive'}` : 'RoutePilot location';
  $('gpxFormat').value = moving ? 'activity' : 'route';
  $('gpxFormat').querySelector('[value="activity"]').disabled = !moving;
  $('gpxPace').value = RouteGPX.speedToPace(gpxDraft.speed, gpxDraft.units);
  $('gpxDuration').value = String(Number((gpxDraft.total/(gpxDraft.speed/3.6)/60).toFixed(4)));
  $('gpxTimingMethod').value = 'pace';
  const exportSeconds = moving ? gpxDraft.total/(RouteGPX.paceToSpeed($('gpxPace').value,gpxDraft.units)/3.6) : 0;
  $('gpxStart').value = RouteGPX.localTime(new Date(Date.now()-exportSeconds*1000));
  $('gpxTimezone').textContent = `(${Intl.DateTimeFormat().resolvedOptions().timeZone})`;
  $('gpxPaceLabel').textContent = `Pace (min/${U.distanceLabel(gpxDraft.units)})`;
  $('gpxRouteSummary').textContent = `${gpxDraft.mode === 'stationary' ? 'Stationary location' : gpxDraft.mode === 'running' ? 'Pedestrian route' : 'Driving route'} · ${U.distanceToDisplay(gpxDraft.total,gpxDraft.units).toFixed(2)} ${U.distanceLabel(gpxDraft.units)}${gpxDraft.loop && moving ? ' · One lap' : ''}`;
  $('gpxError').hidden = $('gpxSuccess').hidden = true;
  renderGPX(); $('gpxDialog').showModal();
};
function gpxSettings() {
  if (!gpxDraft) throw Error('Open the GPX creator again.');
  const format = $('gpxFormat').value, timed = format !== 'route', moving = gpxDraft.total >= .01;
  const name = $('gpxName').value.trim();
  if (!name || name.length > 100) throw Error('Enter a name of 1–100 characters.');
  const speed = !timed || !moving ? gpxDraft.speed : $('gpxTimingMethod').value === 'pace' ? RouteGPX.paceToSpeed($('gpxPace').value,gpxDraft.units) : RouteGPX.durationToSpeed($('gpxDuration').value,gpxDraft.total);
  const seconds = timed ? gpxDraft.total/(speed/3.6) : 0;
  if (seconds > 365*86400) throw Error('This file would run longer than a year. Use a shorter route or faster pace.');
  return {points:gpxDraft.points, mode:gpxDraft.mode, loop:false, name, format, speed, ...(timed ? {start_time:RouteGPX.startTime($('gpxStart').value)} : {})};
}
function renderGPX() {
  if (!gpxDraft || gpxSaving) return;
  const format=$('gpxFormat').value, timed=format!=='route', moving=gpxDraft.total>=.01, pace=$('gpxTimingMethod').value==='pace';
  $('gpxTiming').hidden=!timed; $('gpxMovingTiming').hidden=!moving;
  $('gpxPaceField').hidden=!pace; $('gpxDurationField').hidden=pace;
  $('gpxStart').disabled=!timed; $('gpxPace').disabled=!timed||!moving||!pace; $('gpxDuration').disabled=!timed||!moving||pace;
  $('gpxFormatNote').textContent = timed ? 'Constant pace; live speed variation and lateral drift are not included. No heart rate, elevation, or calories are invented.' : 'An untimed route for planning and navigation. Use a timed track for an activity uploader.';
  $('gpxSuccess').hidden=true;
  try {
    const settings=gpxSettings(), seconds=timed?gpxDraft.total/(settings.speed/3.6):0;
    if (timed) {
      const finish=new Date(new Date(settings.start_time).getTime()+seconds*1000);
      if (!Number.isFinite(finish.getTime()) || finish.getUTCFullYear()>9999) throw Error('The finish time is outside the supported date range.');
      $('gpxSummary').textContent=`${duration(seconds)} · Ends ${finish.toLocaleString()}${finish.getTime()>Date.now()+1000 ? ' · Finish time is in the future' : ''}`;
    } else $('gpxSummary').textContent=`${gpxDraft.points.length.toLocaleString()} route points · No timestamps`;
    $('gpxError').hidden=true; $('gpxDownload').disabled=gpxSaving;
  } catch(error) {
    $('gpxSummary').textContent=''; $('gpxError').textContent=error.message; $('gpxError').hidden=false; $('gpxDownload').disabled=true;
  }
}
$('gpxForm').addEventListener('input',renderGPX);
$('gpxForm').addEventListener('change',renderGPX);
$('gpxForm').onsubmit=async event=>{
  event.preventDefault(); if (gpxSaving) return;
  gpxSaving=true; $('gpxDownload').disabled=true; $('gpxDownload').textContent='Creating…'; $('gpxSuccess').hidden=true;
  let saved=false, message='';
  try {
    const settings=gpxSettings();
    $('gpxForm').querySelectorAll('input,select').forEach(input=>{input.disabled=true;});
    const blob=await api('export',settings,true);
    const url=URL.createObjectURL(blob), link=document.createElement('a');
    link.href=url; link.download=RouteGPX.filename(settings.name); document.body.append(link); link.click(); link.remove();
    setTimeout(()=>URL.revokeObjectURL(url),10000);
    saved=true;
  } catch(error) { message=error.message; }
  finally {
    gpxSaving=false; $('gpxDownload').textContent='Download GPX';
    $('gpxForm').querySelectorAll('input,select').forEach(input=>{input.disabled=false;});
    renderGPX(); $('gpxSuccess').hidden=!saved;
    if (message) { $('gpxError').textContent=message; $('gpxError').hidden=false; }
    renderStatus();
  }
};
$('importButton').onclick = () => { $('fileInput').value = ''; $('fileInput').click(); };
$('fileInput').onchange = () => action(async () => {
  const file = $('fileInput').files[0]; if (!file) return;
  if (file.size > 4000000) throw new Error('Choose a GPX file smaller than 4 MB.');
  const {points} = await api('import', {gpx:await file.text()});
  const latest = await api('status'); acceptState(latest);
  if (state.active) throw new Error('A session started while importing. Stop it before editing checkpoints.');
  remember();
  const count = Math.min(24, points.length);
  draft.waypoints = Array.from({length:count}, (_, i) => points[count === 1 ? 0 : Math.round(i*(points.length-1)/(count-1))]);
  if (count === 1) draft.mode = 'stationary'; else if (draft.mode === 'stationary') draft.mode = 'running';
  draft.loop = false; edited(); fitRoute(); notify(`Imported ${count} checkpoints. The selected movement mode determines the route.`);
});
$('demoButton').onclick = () => {
  if (locked()) return;
  remember(); draft = {...draft, mode:'running', speed:10, loop:false, waypoints:[[37.76945,-122.49050],[37.77090,-122.48725],[37.77175,-122.48213],[37.77034,-122.47885],[37.76821,-122.48087]]}; edited(); fitRoute();
};
async function refreshDevices() {
  if (isConnecting()) return;
  connectionShown = false; $('connectionProgress').hidden = true;
  const revision = ++deviceRefresh;
  $('deviceSelect').replaceChildren(new Option('Looking for USB devices…', ''));
  $('connectButton').disabled = true; $('refreshDevices').disabled = true;
  $('connectionStatus').textContent = 'Looking for USB devices…'; $('connectionStatus').classList.remove('error');
  try {
    const result = await api('devices');
    if (revision !== deviceRefresh || state.device === 'iphone' || isConnecting()) return;
    $('deviceSelect').replaceChildren();
    if (!result.devices.length) { $('deviceSelect').append(new Option('No USB device found', '')); $('connectionStatus').textContent = 'Plug in your iPhone, unlock it, tap Trust, then refresh.'; }
    else { result.devices.forEach((d, i) => $('deviceSelect').append(new Option(`USB iPhone ${result.devices.length > 1 ? i+1 : ''} · …${d.id.slice(-8)}`, d.id))); $('connectionStatus').textContent = 'Device detected. Connecting does not change your location.'; }
  } catch (error) { if (revision === deviceRefresh) { $('connectionStatus').textContent = error.message; $('connectionStatus').classList.add('error'); } }
  finally { if (revision === deviceRefresh) { $('refreshDevices').disabled = busy || isConnecting(); $('connectButton').disabled = busy || isConnecting() || state.device === 'iphone' || !$('deviceSelect').value; } }
}
function renderConnection() {
  const progress = state.connection, connecting = isConnecting();
  if (connectionShown && progress?.device && progress.attempt_id !== ignoredConnectionAttempt && (!$('deviceSelect').value || connecting)) {
    const device = progress.device;
    if ($('deviceSelect').value !== device.id || $('deviceSelect').selectedOptions[0]?.textContent !== device.label) $('deviceSelect').replaceChildren(new Option(device.label, device.id));
  }
  $('deviceSelect').disabled = connecting;
  $('previewButton').disabled = busy || connecting || offline;
  if (connecting) {
    $('connectButton').disabled = $('refreshDevices').disabled = true;
    $('connectButton').textContent = 'Connecting…';
  } else if (connectionShown) {
    $('connectButton').disabled = busy || offline || state.device === 'iphone' || !$('deviceSelect').value;
    $('refreshDevices').disabled = busy || offline;
    $('connectButton').textContent = state.device === 'iphone' ? 'Connected' : 'Try again';
  }
  if (!progress?.attempt_id || progress.attempt_id === ignoredConnectionAttempt) return;
  if (progress.active) connectionShown = true;
  if (!connectionShown) return;
  $('connectionProgress').hidden = false;
  const failed = !!progress.error || !!state.error, current = progress.steps.at(-1);
  $('connectionHeading').textContent = failed ? 'Connection needs attention' : progress.status === 'ready' ? 'iPhone ready' : 'Connecting to iPhone';
  $('connectionElapsed').textContent = `${duration(progress.elapsed)} elapsed`;
  $('connectionSteps').replaceChildren(...progress.steps.map(step => {
    const row = document.createElement('li'); row.className = 'connection-step ' + step.status;
    const icon = document.createElement('span'); icon.className = 'step-icon'; icon.setAttribute('aria-hidden', 'true'); icon.textContent = step.status === 'done' ? '✓' : step.status === 'error' ? '!' : '';
    const label = document.createElement('span'); label.textContent = step.label;
    const elapsed = document.createElement('small'); elapsed.textContent = duration(step.elapsed);
    row.setAttribute('aria-label', `${step.label}: ${step.status === 'done' ? 'complete' : step.status === 'error' ? 'failed' : 'in progress'}, ${Math.floor(step.elapsed)} seconds`);
    row.append(icon, label, elapsed); return row;
  }));
  let message = state.error || (progress.status === 'ready' ? 'Connected. Choose a location or route, then start.' : failed ? `Stopped at “${current?.label || 'Connection'}”. ${progress.error}` : current?.detail || 'Waiting for the iPhone…');
  if (progress.status === 'cleaning') message += ' Closing the incomplete connection before you retry.';
  if (offline) message = 'Live updates interrupted. The connection may still be running. ' + statusError;
  $('connectionStatus').textContent = message; $('connectionStatus').classList.toggle('error', failed || offline);
  $('connectionHint').textContent = offline ? 'Showing the last confirmed step. Updates resume automatically when the controller responds.' : progress.active && !failed && current?.elapsed >= 20 ? 'Still waiting at this step. Elapsed times show where the connection is spending time; your location has not been changed.' : 'Connecting does not change your location. You can close this dialog and reopen progress from the top bar.';
}
$('connectionButton').onclick = () => {
  if (hosted) { $('macDialog').showModal(); return; }
  $('connectionDialog').showModal(); $('connectButton').disabled = state.device === 'iphone' || busy || isConnecting();
  $('connectButton').textContent = state.device === 'iphone' ? 'Connected' : 'Connect';
  if (isConnecting() || state.connection?.status === 'error' || (state.device === 'iphone' && state.connection?.attempt_id)) { connectionShown = true; renderConnection(); }
  else if (state.device === 'iphone') $('connectionStatus').textContent = state.label + ' is connected. Use Preview to restore and disconnect.';
  else refreshDevices();
};
$('refreshDevices').onclick = refreshDevices;
$('connectButton').onclick = async () => {
  if (busy || isConnecting() || offline) return;
  const serial = $('deviceSelect').value;
  if (!serial) return notify('Connect a USB iPhone and refresh the list.', true);
  if (state.active) return notify('Stop the preview before connecting an iPhone.', true);
  deviceRefresh++; busy = true; connectingRequest = true; connectionShown = true;
  ignoredConnectionAttempt = state.connection?.attempt_id; $('connectionProgress').hidden = true; renderDraft();
  $('connectionStatus').classList.remove('error'); $('connectionStatus').textContent = 'Starting the connection… Waiting for the controller’s first update.';
  try { await control('connect', {serial}); notify('iPhone ready. Choose a location or route, then start.'); }
  catch (error) { $('connectionStatus').textContent = error.message; $('connectionStatus').classList.add('error'); }
  finally { busy = false; connectingRequest = false; await poll(); renderDraft(); }
};
$('previewButton').onclick = () => action(async () => { await control('preview'); $('connectionDialog').close(); });
$('helpButton').onclick = () => $('helpDialog').showModal();
document.querySelectorAll('.close-dialog').forEach(button => { button.onclick = () => button.closest('dialog').close(); });
window.addEventListener('beforeunload', event => { if (state.active && state.device === 'iphone') { event.preventDefault(); event.returnValue = ''; } });
edited(); if (draft.waypoints.length) fitRoute(); poll();

function clearSearchSelection() {
  selectedPlace = null;
  if (searchMarker) { map.removeLayer(searchMarker); searchMarker = null; }
}
function clearSearch(clearInput = false) {
  clearSearchSelection();
  if (clearInput) $('locationSearchInput').value = '';
  placeSearch.clear();
}
function renderSearchAvailability() {
  $('locationSearchButton').disabled = offline || placeSearch.state.status === 'loading';
  $('locationSearchButton').textContent = placeSearch.state.status === 'loading' ? 'Searching…' : 'Search';
  $('clearSearchButton').hidden = !$('locationSearchInput').value;
  const full = selectedMode() !== 'stationary' && draft.waypoints.length >= 24;
  $('addSearchPoint').disabled = !selectedPlace || locked() || full;
  $('addSearchPoint').textContent = selectedMode() === 'stationary' ? 'Use this location' : 'Add checkpoint';
  $('searchEditHint').hidden = !selectedPlace || (!locked() && !full);
  $('searchEditHint').textContent = offline ? 'Reconnect to RoutePilot to edit checkpoints.' : state.active ? 'Stop or restore the current session to edit checkpoints.' : isConnecting() || busy ? 'Wait for the device operation to finish before adding a checkpoint.' : full ? 'Remove a checkpoint first (24 maximum).' : '';
}
function renderSearch() {
  const result = placeSearch.state;
  $('searchPanel').hidden = result.status === 'idle' && !selectedPlace;
  $('searchStatus').hidden = !!selectedPlace;
  $('searchStatus').classList.toggle('error', result.status === 'error');
  $('searchStatus').textContent = result.status === 'loading' ? 'Looking for matching places…' : result.status === 'error' ? result.error : result.status === 'ready' ? result.results.length ? 'Select a result to preview it on the map.' : 'No places found. Try adding a city or a more specific address.' : '';
  $('searchResults').replaceChildren();
  if (!selectedPlace) result.results.forEach(place => {
    const row = document.createElement('li'), button = document.createElement('button');
    button.type = 'button'; button.className = 'search-result';
    const name = document.createElement('strong'), description = document.createElement('span');
    name.textContent = place.name; description.textContent = place.description;
    button.append(name, description); button.onclick = () => selectPlace(place); row.append(button); $('searchResults').append(row);
  });
  $('selectedPlace').hidden = !selectedPlace;
  if (selectedPlace) { $('selectedPlaceName').textContent = selectedPlace.name; $('selectedPlaceAddress').textContent = selectedPlace.description; }
  renderSearchAvailability();
}
function selectPlace(place) {
  clearSearchSelection(); selectedPlace = place;
  searchMarker = L.circleMarker(place.point, {radius:9, color:'#fff', weight:3, fillColor:'#397daa', fillOpacity:1, interactive:false}).addTo(map);
  if (place.bounds) map.fitBounds(place.bounds, {paddingTopLeft:[30,120], paddingBottomRight:[45,35], maxZoom:16, animate:false});
  else map.setView(place.point, 16, {animate:false});
  renderSearch();
  // Keep the preview marker visible below the search card on compact screens.
  const card = $('searchPanel').getBoundingClientRect(), mapRect = $('map').getBoundingClientRect();
  const pin = map.latLngToContainerPoint(place.point), covered = mapRect.top + pin.y < card.bottom + 18 && mapRect.left + pin.x < card.right + 18;
  if (covered && card.bottom + 35 < mapRect.bottom) map.panBy([0, -(card.bottom + 30 - mapRect.top - pin.y)], {animate:false});
  $('addSearchPoint').focus({preventScroll:true});
}
$('locationSearchForm').onsubmit = event => {
  event.preventDefault();
  if (offline || placeSearch.state.status === 'loading') return;
  clearSearchSelection(); placeSearch.search($('locationSearchInput').value);
};
$('locationSearchInput').oninput = () => clearSearch();
$('clearSearchButton').onclick = () => { clearSearch(true); $('locationSearchInput').focus({preventScroll:true}); };
$('mapSearch').addEventListener('keydown', event => {
  if (event.key === 'Escape') { event.preventDefault(); event.stopPropagation(); clearSearch(); $('locationSearchInput').focus({preventScroll:true}); }
  if (event.key === 'ArrowDown' && event.target === $('locationSearchInput')) { const first = $('searchResults').querySelector('button'); if (first) { event.preventDefault(); first.focus(); } }
});
$('addSearchPoint').onclick = () => {
  if (!selectedPlace) return;
  const name = selectedPlace.name;
  if (addPoint([...selectedPlace.point])) { clearSearch(true); notify(`${draft.mode === 'stationary' ? 'Location selected' : 'Checkpoint added'}: ${name}`); }
};

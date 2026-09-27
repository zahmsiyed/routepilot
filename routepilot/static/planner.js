/* Automatic routing. Edits are coalesced; stale responses never become playable. */
(function (root) {
  'use strict';
  const validPoint = p => Array.isArray(p) && p.length === 2 && p.every(Number.isFinite) && Math.abs(p[0]) <= 90 && Math.abs(p[1]) <= 180;
  class RoutePlanner {
    constructor(request, onChange, delay = 350) {
      this.request = request;
      this.onChange = onChange;
      this.delay = delay;
      this.revision = 0;
      this.inFlight = false;
      this.timer = null;
      this.pending = null;
      this.state = {status: 'empty', points: [], error: null};
    }
    update(points, mode, loop = false) {
      this.revision++;
      clearTimeout(this.timer);
      this.pending = null;
      if (!['stationary', 'running', 'driving'].includes(mode) || !Array.isArray(points) || points.length > 24 || !points.every(validPoint)) {
        this.publish({status: 'error', points: [], error: 'Check the checkpoint coordinates.'});
        return;
      }
      const copy = points.map(p => [...p]);
      if (mode === 'stationary') {
        this.publish({status: copy.length ? 'ready' : 'empty', points: copy.slice(0, 1), error: null});
        return;
      }
      if (copy.length < 2) {
        this.publish({status: 'empty', points: [], error: null});
        return;
      }
      if (loop && (copy[0][0] !== copy.at(-1)[0] || copy[0][1] !== copy.at(-1)[1])) copy.push([...copy[0]]);
      this.pending = {revision: this.revision, data: {points: copy, mode}};
      this.publish({status: 'routing', points: [], error: null});
      this.timer = setTimeout(() => this.pump(), this.delay);
    }
    publish(state) {
      this.state = state;
      this.onChange(state);
    }
    async pump() {
      if (this.inFlight || !this.pending) return;
      const job = this.pending;
      this.pending = null;
      this.inFlight = true;
      try {
        const result = await this.request(job.data);
        if (job.revision !== this.revision) return;
        const expected = job.data.mode === 'running' ? 'foot' : 'car';
        if (!result || result.profile !== expected || !Array.isArray(result.points) || result.points.length < 2 || result.points.length > 30000 || !result.points.every(validPoint)) {
          throw new Error('A route for this movement mode was not returned. Try again.');
        }
        if (!result.points.some(p => p[0] !== result.points[0][0] || p[1] !== result.points[0][1])) throw new Error('The checkpoints resolve to the same location. Move a checkpoint farther away.');
        this.publish({status: 'ready', points: result.points.map(p => [...p]), error: null});
      } catch (error) {
        if (job.revision === this.revision) {
          this.publish({status: 'error', points: [], error: error?.message || 'Could not find a route. Try moving a checkpoint.'});
        }
      } finally {
        this.inFlight = false;
        if (this.pending) this.timer = setTimeout(() => this.pump(), this.delay);
      }
    }
  }
  root.RoutePlanner = RoutePlanner;
  if (typeof module !== 'undefined' && module.exports) module.exports = RoutePlanner;
})(globalThis);

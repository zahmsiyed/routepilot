/* Explicit searches only; editing or clearing invalidates in-flight results. */
(function(root) {
  'use strict';
  const validPoint = p => Array.isArray(p) && p.length === 2 && p.every(Number.isFinite) && Math.abs(p[0]) <= 90 && Math.abs(p[1]) <= 180;
  class PlaceSearch {
    constructor(request, onChange) {
      this.request = request; this.onChange = onChange; this.revision = 0;
      this.state = {status:'idle', results:[], error:null};
    }
    publish(state) { this.state = state; this.onChange(state); }
    clear() { this.revision++; this.publish({status:'idle', results:[], error:null}); }
    async search(value) {
      const revision = ++this.revision, query = value.trim().replace(/\s+/g, ' ');
      if (query.length < 2 || query.length > 200) {
        this.publish({status:'error', results:[], error:'Enter 2–200 characters for a place name or address.'}); return;
      }
      this.publish({status:'loading', results:[], error:null});
      try {
        const data = await this.request({query});
        if (revision !== this.revision) return;
        if (!data || !Array.isArray(data.results) || data.results.length > 5 || !data.results.every(r => r && typeof r.name === 'string' && r.name.trim() && typeof r.description === 'string' && validPoint(r.point))) throw Error('The search service returned invalid locations. Try again.');
        const results = data.results.map(r => ({...r, point:[...r.point], bounds:Array.isArray(r.bounds) && r.bounds.length===2 && r.bounds.every(validPoint) && r.bounds[0][0]<=r.point[0] && r.point[0]<=r.bounds[1][0] && r.bounds[0][1]<=r.point[1] && r.point[1]<=r.bounds[1][1] ? r.bounds.map(p=>[...p]) : null}));
        this.publish({status:'ready', results, error:null});
      } catch (error) {
        if (revision === this.revision) this.publish({status:'error', results:[], error:error.message || 'Location search failed. Try again.'});
      }
    }
  }
  root.PlaceSearch = PlaceSearch;
  if (typeof module !== 'undefined' && module.exports) module.exports = PlaceSearch;
})(globalThis);

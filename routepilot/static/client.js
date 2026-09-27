/* Bounded requests. Mutating requests are never retried automatically. */
(function(root) {
  'use strict';
  class RouteClient {
    constructor(token, request = (...args) => fetch(...args), timeouts = {}) {
      this.token = token;
      this.request = request;
      this.timeouts = {status:6000, session:10000, devices:12000, search:30000, route:40000, connect:215000, restore:170000, preview:185000, ...timeouts};
    }
    async call(path, data, blob = false) {
      const controller = new AbortController();
      const timeout = this.timeouts[path] ?? 15000;
      let timer;
      const deadline = new Promise((_, reject) => {
        timer = setTimeout(() => {
          reject(new Error(data === undefined || path === 'route' || path === 'search' ? 'The request timed out. Check the connection and retry.' : 'The request timed out. Check session status before trying again; the action may have completed.'));
          controller.abort();
        }, timeout);
      });
      try {
        const operation = (async () => {
          const response = await this.request('/api/' + path, {method:data === undefined ? 'GET' : 'POST', signal:controller.signal, headers:{'X-RoutePilot-Token':this.token, 'Content-Type':'application/json'}, ...(data === undefined ? {} : {body:JSON.stringify(data)})});
          if (!response.ok) {
            let message;
            try { message = (await response.json()).error; } catch (_) {}
            const error = new Error(message || 'The local app could not complete this request.');
            error.status = response.status;
            throw error;
          }
          return blob ? await response.blob() : await response.json();
        })();
        return await Promise.race([operation, deadline]);
      } catch (error) {
        if (error instanceof TypeError) throw new Error('Cannot reach RoutePilot. Check that the local app is running.');
        if (error instanceof SyntaxError) throw new Error('The controller returned an invalid response. Reload the page.');
        throw error;
      } finally { clearTimeout(timer); }
    }
  }
  class RouteState {
    constructor() { this.value = null; }
    accept(next) {
      if (!next || !Number.isInteger(next.revision) || next.revision < 0 || typeof next.active !== 'boolean' || !['preview','iphone'].includes(next.device)) throw new Error('The controller returned an invalid status. Reload the page.');
      if (this.value && next.revision < this.value.revision) return false;
      this.value = next;
      return true;
    }
  }
  root.RouteClient = RouteClient;
  root.RouteState = RouteState;
  if (typeof module !== 'undefined' && module.exports) module.exports = {RouteClient, RouteState};
})(globalThis);

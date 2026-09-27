"""Stateless Vercel endpoints. Physical device control stays on the Mac."""
import json
import logging
import threading
import time
from collections import OrderedDict
from http.server import BaseHTTPRequestHandler
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urlsplit
from urllib.request import Request, urlopen

from routepilot_cloud.routes import Route, export_gpx, parse_gpx
from routepilot_cloud.routing import parse_route_response
from routepilot_cloud.geocoding import parse_places, search_query

MAX_BODY = 4_000_000
LOCKS = {name: threading.Lock() for name in ('search', 'route')}
LAST = dict.fromkeys(LOCKS, 0.0)
CACHE = {name: OrderedDict() for name in LOCKS}


def remote(kind, url, maximum):
    # Best-effort per-instance provider pacing, bounded queues and warm caches.
    # No session state, phone identifiers, or USB libraries exist in this runtime.
    if not LOCKS[kind].acquire(timeout=2):
        raise ValueError('The service is busy. Wait a moment, then retry.')
    try:
        now = time.monotonic()
        cache = CACHE[kind]
        if url in cache and now - cache[url][0] < 3600:
            cache.move_to_end(url)
            return cache[url][1]
        time.sleep(max(0, 1.1 - (now - LAST[kind])))
        LAST[kind] = time.monotonic()
        request = Request(url, headers={'User-Agent': 'RoutePilot/1.0 (personal route planner)'})
        try:
            with urlopen(request, timeout=20) as response:
                result = bytearray()
                while chunk := response.read(65536):
                    result.extend(chunk)
                    if len(result) > maximum:
                        raise ValueError('The provider response is too large. Use a smaller route or more specific search.')
                    if time.monotonic() - LAST[kind] > 25:
                        raise ValueError('The provider timed out. Retry in a moment.')
        except HTTPError as exc:
            raise ValueError('The provider is busy. Retry in a moment.' if exc.code == 429 else 'The provider is unavailable. Retry in a moment.') from None
        except (URLError, TimeoutError, OSError):
            raise ValueError('Could not reach the provider. Retry in a moment.') from None
        # Cache only validated responses and bound both entry count and memory.
        value = parse_places(result) if kind == 'search' else parse_route_response(result)
        cache[url] = (time.monotonic(), value)
        while len(cache) > (64 if kind == 'search' else 8):
            cache.popitem(last=False)
        return value
    finally:
        LOCKS[kind].release()


def dispatch(action, data):
    if action == 'search':
        query = search_query(data.get('query'))
        url = 'https://photon.komoot.io/api/?' + urlencode({'q': query, 'limit': 5, 'lang': 'en'})
        return {'results': remote('search', url, 1_000_000)}
    if action == 'route':
        points = Route(data.get('points')).points
        if not 2 <= len(points) <= 25:
            raise ValueError('Routing needs 2–25 distinct checkpoints.')
        if data.get('mode') not in ('running', 'driving'):
            raise ValueError('Choose running or driving to build a route.')
        profile = 'foot' if data['mode'] == 'running' else 'car'
        coords = ';'.join(f'{lon:.6f},{lat:.6f}' for lat, lon in points)
        url = f'https://routing.openstreetmap.de/routed-{profile}/route/v1/driving/{coords}?overview=full&geometries=geojson&steps=false'
        route = remote('route', url, 4_000_000)
        return {'points': route.points, 'distance': route.total, 'profile': profile}
    if action == 'import':
        xml = data.get('gpx')
        if not isinstance(xml, str) or len(xml.encode('utf-8')) > 3_500_000:
            raise ValueError('Choose a GPX file smaller than 3.5 MB for the hosted app.')
        return {'points': parse_gpx(xml)}
    if action == 'export':
        result = export_gpx(Route(data.get('points'), data.get('loop', False)), data.get('speed', 10), data.get('name', 'RoutePilot route'))
        if len(result) > MAX_BODY:
            raise ValueError('This GPX is too large for the hosted app. Export it with the Mac controller or use a shorter route.')
        return result
    raise ValueError('This endpoint is unavailable. Use the Mac controller for iPhone control.')


class handler(BaseHTTPRequestHandler):
    def respond(self, status, value):
        is_gpx = isinstance(value, bytes)
        payload = value if is_gpx else json.dumps(value, allow_nan=False).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/gpx+xml; charset=utf-8' if is_gpx else 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Content-Length', str(len(payload)))
        if is_gpx:
            self.send_header('Content-Disposition', 'attachment; filename="routepilot.gpx"')
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        self.respond(405, {'error': 'Use POST for planner requests.'})

    def do_POST(self):
        origin = self.headers.get('Origin')
        if self.headers.get('Sec-Fetch-Site') == 'cross-site' or (origin and urlsplit(origin).netloc != self.headers.get('Host')):
            return self.respond(403, {'error': 'Open the planner on its own website.'})
        try:
            if self.headers.get('Content-Type', '').split(';')[0].strip() != 'application/json':
                return self.respond(415, {'error': 'Send JSON.'})
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= MAX_BODY:
                return self.respond(413, {'error': 'Request too large. Use a smaller GPX file or fewer route points.'})
            raw = self.rfile.read(length)
            if len(raw) != length:
                raise ValueError('The request was incomplete. Retry.')
            try:
                data = json.loads(raw, parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))
            except (ValueError, UnicodeError):
                raise ValueError('Send valid JSON with finite numbers.') from None
            if not isinstance(data, dict):
                raise ValueError('Send a JSON object.')
            url = urlsplit(self.path)
            action = parse_qs(url.query).get('action', [url.path.rsplit('/', 1)[-1]])[0]
            if action not in ('search', 'route', 'import', 'export'):
                return self.respond(404, {'error': 'Planner endpoint not found.'})
            result = dispatch(action, data)
            return self.respond(200, result)
        except (ValueError, TypeError, OverflowError) as exc:
            return self.respond(400, {'error': str(exc) or 'Invalid request.'})
        except Exception:
            logging.exception('Hosted planner request failed')
            return self.respond(503, {'error': 'The hosted planner could not complete this request. Retry in a moment.'})

import asyncio
import hmac
import logging
import secrets
import time
from pathlib import Path
from aiohttp import ClientError, ClientSession, ClientTimeout, web
from .device import IPhoneDevice, PreviewDevice, list_devices, friendly_error
from .engine import Engine
from .connection import ConnectionProgress
from .geocoding import Geocoder
from .routes import Route, export_gpx, parse_gpx
from .routing import parse_route_response, MAX_RESPONSE_BYTES

STATIC = Path(__file__).parent / 'static'
LOG = logging.getLogger(__name__)
ENGINE = web.AppKey('engine', Engine)
TOKEN = web.AppKey('token', str)
CONTROL = web.AppKey('control', asyncio.Lock)
NETWORK_LOCK = web.AppKey('network_lock', asyncio.Lock)
LAST_ROUTE = web.AppKey('last_route', float)
PORT = web.AppKey('port', int)
CONNECTION = web.AppKey('connection', ConnectionProgress)
GEOCODER = web.AppKey('geocoder', Geocoder)


@web.middleware
async def guard(request, handler):
    port = request.app[PORT]
    allowed = {f'127.0.0.1:{port}', f'localhost:{port}'}
    if request.host not in allowed:
        raise web.HTTPForbidden(text='Local access only.')
    if request.headers.get('Sec-Fetch-Site') == 'cross-site':
        raise web.HTTPForbidden(text='Cross-site access is disabled.')
    origin = request.headers.get('Origin')
    if origin and origin not in {f'http://{host}' for host in allowed}:
        raise web.HTTPForbidden(text='Unrecognized origin.')
    if request.path.startswith('/api/') and not hmac.compare_digest(
        request.headers.get('X-RoutePilot-Token', ''), request.app[TOKEN]
    ):
        return web.json_response({'error': 'Session expired. Reload RoutePilot.'}, status=403)
    try:
        response = await handler(request)
    except (ValueError, RuntimeError) as exc:
        response = web.json_response({'error': str(exc)}, status=400)
    except web.HTTPException as exc:
        response = web.json_response({'error': exc.reason}, status=exc.status)
    except Exception as exc:
        LOG.exception('Request failed')
        response = web.json_response({'error': friendly_error(exc)}, status=503)
    response.headers.update({
        'Cache-Control': 'no-store',
        'X-Content-Type-Options': 'nosniff',
        'Referrer-Policy': 'strict-origin-when-cross-origin',
        'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https://tile.openstreetmap.org; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'",
    })
    return response


async def body(request):
    try:
        data = await request.json()
    except web.HTTPRequestEntityTooLarge:
        raise
    except Exception:
        raise ValueError('Send valid JSON.') from None
    if not isinstance(data, dict):
        raise ValueError('Send a JSON object.')
    return data


async def index(request):
    html = (STATIC / 'index.html').read_text().replace('__SESSION_TOKEN__', request.app[TOKEN])
    return web.Response(text=html, content_type='text/html')


async def status(request):
    return web.json_response(snapshot(request.app))


def snapshot(app):
    return {**app[ENGINE].snapshot(), 'connection': app[CONNECTION].snapshot()}


async def session(request):
    return web.json_response({**request.app[ENGINE].session(), 'connection': request.app[CONNECTION].snapshot()})


async def devices(request):
    return web.json_response({'devices': await list_devices()})


async def search_places(request):
    data = await body(request)
    return web.json_response({'results': await request.app[GEOCODER].search(data.get('query'))})


async def command(request):
    data = await body(request)
    engine = request.app[ENGINE]
    action = request.match_info['action']
    try:
        await asyncio.wait_for(request.app[CONTROL].acquire(), 3)
    except TimeoutError:
        raise web.HTTPConflict(reason='Another device operation is still finishing. Check status and retry.') from None
    try:
        if 'session_id' in data and data['session_id'] != engine.session_id:
            raise web.HTTPConflict(reason='The active session changed. Refresh status before trying again.')
        if action == 'start':
            await engine.start(data)
        elif action == 'pause':
            await engine.pause(data.get('paused'))
        elif action == 'speed':
            await engine.set_speed(data.get('speed'))
        elif action == 'motion':
            await engine.set_motion(data)
        elif action == 'restore':
            await engine.restore()
        elif action == 'preview':
            await engine.replace_device(PreviewDevice())
            request.app[CONNECTION].reset()
        elif action == 'connect':
            if engine.device.kind == 'iphone':
                raise ValueError('An iPhone is already connected. Use Restore or switch to Preview first.')
            if engine.active:
                raise ValueError('Stop the preview before connecting an iPhone.')
            progress = request.app[CONNECTION]
            progress.start()
            device = None
            try:
                available = await list_devices()
                serial = data.get('serial')
                if not available:
                    raise ValueError('No USB iPhone found. Plug it in, unlock it, and tap Trust This Computer.')
                if serial is None:
                    if len(available) != 1:
                        raise ValueError('Select the iPhone to connect.')
                    serial = available[0]['id']
                if not isinstance(serial, str) or serial not in {d['id'] for d in available}:
                    raise ValueError('Choose a connected USB device.')
                progress.select_device(serial)
                device = IPhoneDevice(serial)
                await asyncio.wait_for(device.open(progress=progress), 180)
                await engine.replace_device(device)
                progress.ready()
            except BaseException as exc:
                message = (progress.error or friendly_error(exc)) if isinstance(exc, (TimeoutError, asyncio.CancelledError)) else friendly_error(exc)
                progress.failed(message, cleaning=device is not None)
                if device is not None:
                    try:
                        await device.close()
                    except Exception:
                        LOG.warning('Device cleanup failed after a connection error', exc_info=True)
                progress.failed(message)
                raise
        else:
            raise web.HTTPNotFound()
    finally:
        request.app[CONTROL].release()
    return web.json_response(snapshot(request.app))


async def import_route(request):
    data = await body(request)
    xml = data.get('gpx')
    if not isinstance(xml, str) or len(xml) > 4_000_000:
        raise ValueError('Choose a GPX file smaller than 4 MB.')
    return web.json_response({'points': await asyncio.to_thread(parse_gpx, xml)})


async def export_route(request):
    data = await body(request)
    route = Route(data.get('points'), data.get('loop', False))
    exported = await asyncio.to_thread(export_gpx, route, data.get('speed', 10), data.get('name', 'RoutePilot route'))
    return web.Response(body=exported,
                        content_type='application/gpx+xml',
                        headers={'Content-Disposition': 'attachment; filename="routepilot.gpx"'})


async def snap_route(request):
    data = await body(request)
    points = Route(data.get('points')).points
    if not 2 <= len(points) <= 25:
        raise ValueError('Road/path routing needs 2–25 waypoints. Import GPX for longer routes.')
    mode = data.get('mode')
    if mode not in ('running', 'driving'):
        raise ValueError('Choose running or driving to build a route.')
    profile = 'foot' if mode == 'running' else 'car'
    coords = ';'.join(f'{lon:.6f},{lat:.6f}' for lat, lon in points)
    url = f'https://routing.openstreetmap.de/routed-{profile}/route/v1/driving/{coords}'
    async def fetch_route():
        # The deadline includes queueing, so multiple tabs cannot wait forever.
        async with request.app[NETWORK_LOCK]:
            delay = 1.05 - (time.monotonic() - request.app[LAST_ROUTE])
            if delay > 0:
                await asyncio.sleep(delay)
            request.app[LAST_ROUTE] = time.monotonic()
            async with ClientSession(timeout=ClientTimeout(total=25), headers={'User-Agent': 'RoutePilot/1.0 (local personal route planner)'}) as client:
                async with client.get(url, params={'overview': 'full', 'geometries': 'geojson', 'steps': 'false'}) as response:
                    if response.status == 429:
                        raise ValueError('Routing is busy. Wait a moment, then retry.')
                    if response.status != 200:
                        raise ValueError('The routing service is unavailable. Retry in a moment.')
                    raw = bytearray()
                    async for chunk in response.content.iter_chunked(65536):
                        raw.extend(chunk)
                        if len(raw) > MAX_RESPONSE_BYTES:
                            raise ValueError('The routing response is too large. Use fewer or closer checkpoints.')
                    return parse_route_response(raw)
    try:
        routed = await asyncio.wait_for(fetch_route(), 30)
    except TimeoutError:
        raise ValueError('Routing timed out. Check your internet connection and retry.') from None
    except ClientError:
        raise ValueError('Could not reach the routing service. Check your internet connection and retry.') from None
    return web.json_response({'points': routed.points, 'distance': routed.total, 'profile': profile})


async def shutdown(app):
    try:
        await app[ENGINE].close()
    except Exception:
        LOG.exception('GPS restore was not confirmed. Reconnect and Restore, or restart your iPhone.')


def create_app(port=8765, engine=None):
    app = web.Application(middlewares=[guard], client_max_size=6_000_000)
    app[ENGINE] = engine or Engine()
    app[CONNECTION] = ConnectionProgress(app[ENGINE].touch)
    app[GEOCODER] = Geocoder()
    app[TOKEN] = secrets.token_urlsafe(32)
    app[CONTROL] = asyncio.Lock()
    app[NETWORK_LOCK] = asyncio.Lock()
    app[LAST_ROUTE] = 0.0
    app[PORT] = port
    app.router.add_get('/', index)
    app.router.add_get('/api/status', status)
    app.router.add_get('/api/session', session)
    app.router.add_get('/api/devices', devices)
    app.router.add_post('/api/import', import_route)
    app.router.add_post('/api/export', export_route)
    app.router.add_post('/api/route', snap_route)
    app.router.add_post('/api/search', search_places)
    app.router.add_post('/api/{action}', command)
    app.router.add_static('/static/', STATIC, show_index=False)
    app.on_cleanup.append(shutdown)
    return app

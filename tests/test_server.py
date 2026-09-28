import pytest
from aiohttp.test_utils import TestClient, TestServer
from routepilot.server import create_app, PORT, TOKEN


@pytest.fixture
async def client():
    app=create_app()
    server=TestServer(app);await server.start_server();app[PORT]=server.port
    client=TestClient(server);await client.start_server()
    client.session.headers['X-RoutePilot-Token']=app[TOKEN]
    yield client
    await client.close()


@pytest.mark.asyncio
async def test_api_requires_session_and_local_origin(client):
    response=await client.post('/api/start',json={},headers={'X-RoutePilot-Token':'wrong'})
    assert response.status==403
    response=await client.get('/api/status',headers={'Origin':'https://example.com'})
    assert response.status==403
    response=await client.get('/api/status',headers={'Host':'attacker.example'})
    assert response.status==403


@pytest.mark.asyncio
async def test_preview_lifecycle_and_export(client):
    r=await client.post('/api/start',json={'points':[[1,2]],'mode':'stationary'})
    assert r.status==200 and (await r.json())['phase']=='holding'
    r=await client.get('/api/status');assert (await r.json())['device']=='preview'
    r=await client.post('/api/export',json={'points':[[1,2],[1.001,2.001]],'speed':10})
    assert r.status==200 and b'<gpx ' in await r.read()
    r=await client.post('/api/restore',json={});assert (await r.json())['active'] is False


@pytest.mark.asyncio
async def test_gpx_creator_exports_without_changing_active_session(client):
    from xml.etree import ElementTree as ET
    await client.post('/api/start', json={'points': [[1, 2]], 'mode': 'stationary'})
    before = await (await client.get('/api/status')).json()
    data = {'points': [[37, -122], [37.001, -122]], 'mode': 'running', 'format': 'activity', 'name': 'Simulated run', 'speed': 12, 'start_time': '2026-09-27T08:00:00Z'}
    response = await client.post('/api/export', json=data)
    assert response.status == 200
    ns = {'g': 'http://www.topografix.com/GPX/1/1'}
    root = ET.fromstring(await response.read())
    assert root.find('g:trk/g:trkseg/g:trkpt/g:time', ns).text == '2026-09-27T08:00:00.000000Z'
    assert root.find('g:wpt', ns) is None
    after = await (await client.get('/api/status')).json()
    assert after['active'] and after['session_id'] == before['session_id'] and after['position'] == before['position']
    assert (await client.post('/api/export', json={**data, 'start_time': 'invalid'})).status == 400


@pytest.mark.asyncio
async def test_bad_inputs_are_explained(client):
    r=await client.post('/api/start',json={'points':[[91,0]]});assert r.status==400
    r=await client.post('/api/start',json=[]);assert r.status==400
    r=await client.post('/api/import',json={'gpx':'not xml'});assert r.status==400
    r=await client.post('/api/route',json={'points':[[1,2]],'mode':'driving'});assert r.status==400
    r=await client.post('/api/search',json={'query':''});assert r.status==400


@pytest.mark.asyncio
async def test_search_requires_token_and_does_not_wait_for_device_control(client):
    import routepilot.server as server
    r=await client.post('/api/search',json={'query':'Park'},headers={'X-RoutePilot-Token':'wrong'})
    assert r.status==403
    queries=[]
    async def lookup(query):queries.append(query);return [{'name':'Park','description':'City','point':[1,2],'bounds':None}]
    client.server.app[server.GEOCODER].search=lookup
    async with client.server.app[server.CONTROL]:
        r=await client.post('/api/search',json={'query':'Park'})
        assert r.status==200 and (await r.json())['results'][0]['point']==[1,2]
    assert queries==['Park']
    state=await (await client.get('/api/status')).json()
    assert state['device']=='preview' and not state['active']


@pytest.mark.asyncio
async def test_motion_endpoint_updates_and_validates_atomically(client):
    r = await client.post('/api/start', json={'mode':'running', 'points':[[0,0],[0,.1]], 'speed':10, 'speed_variation':1, 'lateral_variation':.5})
    data = await r.json()
    assert r.status == 200 and data['speed_variation'] == 1 and data['lateral_variation'] == .5
    r = await client.post('/api/motion', json={'speed':20, 'speed_variation':3, 'lateral_variation':.75})
    data = await r.json()
    assert r.status == 200 and data['speed'] == 20 and data['speed_variation'] == 3 and data['lateral_variation'] == .75
    r = await client.post('/api/motion', json={'speed':40, 'lateral_variation':2.01})
    assert r.status == 400
    data = await (await client.get('/api/status')).json()
    assert data['speed'] == 20 and data['lateral_variation'] == .75 and data['active']


@pytest.mark.asyncio
async def test_stale_session_commands_cannot_control_a_new_route(client):
    start={'mode':'stationary','points':[[1,2]],'session_id':None}
    first=await (await client.post('/api/start',json=start)).json()
    duplicate=await client.post('/api/start',json=start)
    assert duplicate.status==409
    await client.post('/api/restore',json={'session_id':first['session_id']})
    second=await (await client.post('/api/start',json=start)).json()
    stale=await client.post('/api/restore',json={'session_id':first['session_id']})
    assert stale.status==409
    now=await (await client.get('/api/status')).json()
    assert now['active'] and now['session_id']==second['session_id']


@pytest.mark.asyncio
async def test_session_geometry_can_recover_an_active_route_after_reload(client):
    points=[[0,0],[0,.01],[.01,.01]]
    checkpoints=[[0,0],[.01,.01]]
    started=await (await client.post('/api/start',json={'points':points,'checkpoints':checkpoints})).json()
    session=await (await client.get('/api/session')).json()
    assert session['points']==points and session['checkpoints']==checkpoints
    assert session['session_id']==started['session_id']
    assert 'points' not in await (await client.get('/api/status')).json()


@pytest.mark.asyncio
async def test_large_json_body_has_an_actionable_413(client):
    result=await client.post('/api/import',data=b'{"gpx":"'+b'x'*6_000_001+b'"}',headers={'Content-Type':'application/json'})
    assert result.status==413
    assert 'error' in await result.json()


@pytest.mark.asyncio
async def test_routing_failures_are_explained_without_a_fallback(client,monkeypatch):
    import routepilot.server as server
    from aiohttp import ClientConnectionError
    class Content:
        async def iter_chunked(self,size):yield b'<html>broken provider</html>'
    class Response:
        status=503;content=Content()
        async def __aenter__(self):return self
        async def __aexit__(self,*args):pass
    class Session:
        async def __aenter__(self):return self
        async def __aexit__(self,*args):pass
        def get(self,*args,**kwargs):return Response()
    monkeypatch.setattr(server,'ClientSession',lambda **kwargs:Session())
    data={'points':[[1,2],[1.01,2.01]],'mode':'running'}
    for code,expected in [(503,'unavailable'),(429,'busy'),(200,'invalid route')]:
        Response.status=code
        client.server.app[server.LAST_ROUTE]=0
        r=await client.post('/api/route',json=data)
        assert r.status==400 and expected in (await r.json())['error']
    def disconnected(*args,**kwargs):raise ClientConnectionError()
    monkeypatch.setattr(Session,'get',disconnected)
    client.server.app[server.LAST_ROUTE]=0
    r=await client.post('/api/route',json=data)
    assert r.status==400 and 'reach the routing service' in (await r.json())['error']


@pytest.mark.asyncio
async def test_connection_error_survives_a_cleanup_error(client,monkeypatch):
    import routepilot.server as server
    async def devices():return [{'id':'fake','connection':'USB'}]
    class FailedDevice:
        def __init__(self,serial):pass
        async def open(self,progress=None):raise RuntimeError('Trust the iPhone first')
        async def close(self):raise RuntimeError('Cleanup also failed')
    monkeypatch.setattr(server,'list_devices',devices)
    monkeypatch.setattr(server,'IPhoneDevice',FailedDevice)
    r=await client.post('/api/connect',json={'serial':'fake'})
    assert r.status==400 and 'Trust the iPhone first' in (await r.json())['error']
    state=await (await client.get('/api/status')).json()
    assert not state['active'] and state['device']=='preview'
    assert state['connection']['status']=='error' and not state['connection']['active']


@pytest.mark.asyncio
async def test_connection_progress_is_live_while_connect_is_pending_and_persists(client,monkeypatch):
    import asyncio
    import routepilot.server as server
    started=asyncio.Event();release=asyncio.Event()
    class Phone:
        kind='iphone';label='Test iPhone'
        def __init__(self,serial):pass
        async def open(self,progress=None):
            progress.step('trust','Connecting over USB','Unlock and Trust.')
            progress.step('tunnel','Opening the secure connection','Waiting for the iPhone.')
            started.set();await release.wait()
        async def close(self):pass
        async def clear(self):pass
    async def devices():return [{'id':'fake','connection':'USB'}]
    monkeypatch.setattr(server,'IPhoneDevice',Phone);monkeypatch.setattr(server,'list_devices',devices)
    request=asyncio.create_task(client.post('/api/connect',json={'serial':'fake'}))
    await asyncio.wait_for(started.wait(),1)
    live=await asyncio.wait_for(client.get('/api/status'),1);data=await live.json()
    assert not request.done() and data['connection']['active']
    assert data['connection']['steps'][-1]['key']=='tunnel'
    assert data['connection']['steps'][-2]['status']=='done'
    recovered=await (await client.get('/api/session')).json()
    assert recovered['connection']['attempt_id']==data['connection']['attempt_id']
    release.set();result=await (await request).json()
    assert result['device']=='iphone' and result['connection']['status']=='ready'
    assert all(step['status']=='done' for step in result['connection']['steps'])
    assert result['revision']>data['revision']
    await client.post('/api/preview',json={})
    assert (await (await client.get('/api/status')).json())['connection']['status']=='idle'


@pytest.mark.asyncio
async def test_missing_usb_failure_records_stage_and_retry_has_new_attempt(client,monkeypatch):
    import routepilot.server as server
    async def devices():return []
    monkeypatch.setattr(server,'list_devices',devices)
    attempts=[]
    for _ in range(2):
        assert (await client.post('/api/connect',json={})).status==400
        progress=(await (await client.get('/api/status')).json())['connection']
        assert progress['status']=='error' and 'No USB iPhone' in progress['error']
        assert len(progress['steps'])==1 and progress['steps'][0]['status']=='error'
        attempts.append(progress['attempt_id'])
    assert attempts[0]!=attempts[1]

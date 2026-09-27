import asyncio
import json
import pytest
from routepilot.engine import Engine
from routepilot.device import IPhoneDevice
from routepilot.routes import Route, coordinate, speed_value, parse_gpx, export_gpx, MAX_POINTS
from routepilot.motion import bounded_value
from routepilot.routing import parse_route_response


@pytest.mark.asyncio
async def test_duplicate_start_does_not_restart_or_teleport():
    engine=Engine()
    await engine.start({'mode':'stationary','points':[[1,2]]})
    original=engine.session_id
    with pytest.raises(ValueError,match='current session'):
        await engine.start({'mode':'stationary','points':[[3,4]]})
    assert engine.position==(1,2) and engine.session_id==original
    await engine.restore()
    await engine.start({'mode':'stationary','points':[[3,4]]})
    assert engine.session_id!=original
    await engine.close()


@pytest.mark.asyncio
async def test_pause_is_idempotent_and_revision_never_moves_backwards():
    engine=Engine()
    await engine.start({'points':[[0,0],[0,.1]]})
    revision=engine.revision
    await engine.pause(True); paused=engine.revision
    await engine.pause(True)
    assert engine.phase=='paused' and paused>revision and engine.revision==paused
    await engine.pause(False); resumed=engine.revision
    await engine.pause(False)
    assert engine.phase=='playing' and resumed>paused and engine.revision==resumed
    with pytest.raises(ValueError): await engine.pause('false')
    await engine.close()


@pytest.mark.asyncio
async def test_pause_waits_for_an_inflight_write_then_holds_and_detects_disconnect():
    class SlowPhone:
        kind='iphone'; label='Fake'
        def __init__(self):
            self.calls=[];self.writing=asyncio.Event();self.release=asyncio.Event();self.fail=False
        async def set(self,*point):
            if self.calls and not self.release.is_set():
                self.writing.set();await self.release.wait()
            if self.fail:raise ConnectionError('Disconnected')
            self.calls.append(point)
        async def clear(self):pass
        async def close(self):pass
    phone=SlowPhone();engine=Engine(.01);await engine.replace_device(phone)
    await engine.start({'points':[[0,0],[0,.1]]})
    await asyncio.wait_for(phone.writing.wait(),1)
    pause=asyncio.create_task(engine.pause(True))
    await asyncio.sleep(0)
    assert not pause.done()
    phone.release.set();await asyncio.wait_for(pause,1)
    held=engine.position
    await asyncio.sleep(.025)
    assert engine.position==held and phone.calls[-1]==held
    phone.fail=True;await asyncio.sleep(.025)
    assert engine.phase=='error' and engine.active
    await engine.close()


@pytest.mark.asyncio
async def test_cancelled_first_write_keeps_recovery_required():
    class Phone:
        kind='iphone';label='Fake'
        async def set(self,*point):await asyncio.Event().wait()
        async def clear(self):pass
        async def close(self):pass
    engine=Engine();await engine.replace_device(Phone())
    task=asyncio.create_task(engine.start({'mode':'stationary','points':[[1,2]]}))
    await asyncio.sleep(0);task.cancel()
    with pytest.raises(asyncio.CancelledError):await task
    assert engine.active and engine.phase=='error' and engine.session_id
    await engine.restore();assert not engine.active
    await engine.close()


@pytest.mark.asyncio
async def test_failed_clear_on_an_idle_phone_does_not_claim_safe_state():
    class Phone:
        kind='iphone';label='Fake';fails=True
        async def set(self,*point):pass
        async def clear(self):
            if self.fails:raise ConnectionError('Disconnected')
        async def close(self):pass
    phone=Phone();engine=Engine();await engine.replace_device(phone)
    with pytest.raises(RuntimeError):await engine.restore()
    assert engine.active and engine.phase=='error'
    with pytest.raises(ValueError):await engine.start({'mode':'stationary','points':[[1,2]]})
    phone.fails=False;await engine.close()


@pytest.mark.asyncio
async def test_failed_transport_cleanup_drops_stale_simulator_reference():
    class BrokenStack:
        async def aclose(self):raise RuntimeError('Close failed')
    device=IPhoneDevice('fake');device.stack=BrokenStack();device.simulation=object()
    with pytest.raises(RuntimeError):await device.close()
    assert device.stack is None and device.simulation is None
    with pytest.raises(RuntimeError,match='closed'):await device.set(1,2)


@pytest.mark.asyncio
async def test_clear_reopens_the_same_device_and_retries_once():
    class Simulation:
        def __init__(self,fails=False):self.fails=fails;self.clears=0
        async def clear(self):
            self.clears+=1
            if self.fails:raise ConnectionError('USB')
    old,new=Simulation(True),Simulation()
    device=IPhoneDevice('same-device');device.simulation=old
    opened=[]
    async def reopen():opened.append(device.serial);device.simulation=new
    device.open=reopen
    await device.clear()
    assert opened==['same-device'] and old.clears==new.clears==1
    await device.close()


@pytest.mark.parametrize('operation',[lambda:coordinate([10**400,0]),lambda:speed_value(10**400),lambda:bounded_value(10**400,2,'Drift')])
def test_enormous_json_numbers_produce_validation_errors(operation):
    with pytest.raises(ValueError):operation()


def response(points):return json.dumps({'code':'Ok','routes':[{'geometry':{'type':'LineString','coordinates':points}}]})


@pytest.mark.parametrize('raw',[b'not json',b'[]',b'{"code":"Ok","routes":[null]}',b'{"code":"Ok","routes":[]}',response([[1,2]]),response([[1,2],[1,2]]),response([[1,2],None]),response([[1,2],[181,0]])])
def test_bad_provider_data_is_rejected(raw):
    with pytest.raises(ValueError):parse_route_response(raw)


def test_valid_provider_geometry_preserves_coordinate_order():
    assert parse_route_response(response([[2,1],[2.1,1.1]])).points==[(1,2),(1.1,2.1)]


def test_gpx_extension_only_segments_do_not_hide_valid_track():
    xml='<gpx><trk><trkseg><extensions/></trkseg><trkseg><trkpt lat="1" lon="2"/><trkpt lat="1.01" lon="2"/></trkseg></trk></gpx>'
    assert parse_gpx(xml)==[(1,2),(1.01,2)]


def test_maximum_loop_reserves_its_return_point():
    points=[[0,i/10000] for i in range(MAX_POINTS)]
    with pytest.raises(ValueError,match='return point'):Route(points,True)


def test_gpx_export_keeps_exact_endpoint_after_float_roundtrip():
    route=Route([[22.32198765,11.23456789],[22.32287654,11.25432198]])
    assert parse_gpx(export_gpx(route,31.4159))[-1]==route.points[-1]

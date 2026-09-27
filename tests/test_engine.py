import asyncio
import pytest
from routepilot.engine import Engine


class FakePhone:
    kind='iphone'
    label='Test iPhone'
    def __init__(self):self.calls=[];self.fail_set=False;self.fail_clear=False
    async def set(self,*p):
        self.calls.append(('set',p))
        if self.fail_set:raise ConnectionError('USB disconnected')
    async def clear(self):
        self.calls.append(('clear',))
        if self.fail_clear:raise ConnectionError('USB disconnected')
    async def close(self):self.calls.append(('close',))


@pytest.mark.asyncio
async def test_stationary_writes_exact_location_and_restores():
    engine=Engine(.01);phone=FakePhone();await engine.replace_device(phone)
    await engine.start({'mode':'stationary','points':[[10,20]]})
    await asyncio.sleep(.025)
    assert engine.phase=='holding' and engine.position==(10,20)
    assert all(call[1]==(10,20) for call in phone.calls if call[0]=='set')
    await engine.restore()
    count=len(phone.calls);await asyncio.sleep(.025)
    assert len(phone.calls)==count
    assert phone.calls[-1]==('clear',) and not engine.active
    await engine.close()


@pytest.mark.asyncio
async def test_pause_resume_and_speed_change():
    engine=Engine(.01)
    await engine.start({'mode':'running','points':[[0,0],[0,.1]],'speed':36})
    await asyncio.sleep(.035)
    assert engine.meters>0
    await engine.pause();position=engine.position;meters=engine.meters
    await asyncio.sleep(.04)
    assert engine.position==position and engine.meters==meters
    await engine.set_speed(72);await engine.pause();await asyncio.sleep(.035)
    assert engine.meters>meters and engine.speed==72
    await engine.close()


@pytest.mark.asyncio
async def test_finish_holds_endpoint_until_restore():
    engine=Engine(.01)
    await engine.start({'mode':'driving','points':[[0,0],[0,.00001]],'speed':250})
    await asyncio.sleep(.08)
    assert engine.phase=='completed' and engine.position==(0,.00001)
    assert engine.active
    await engine.restore();assert not engine.active


@pytest.mark.asyncio
async def test_loop_continues_without_finishing():
    engine=Engine(.01)
    await engine.start({'mode':'running','points':[[0,0],[0,.00001]],'speed':250,'loop':True})
    await asyncio.sleep(.1)
    assert engine.laps>0 and engine.phase=='playing'
    assert 0<=engine.meters<engine.route.total
    await engine.close()


@pytest.mark.asyncio
async def test_failed_restore_never_claims_real_gps_or_allows_switch():
    engine=Engine(.01);phone=FakePhone();await engine.replace_device(phone)
    await engine.start({'mode':'stationary','points':[[10,20]]})
    phone.fail_clear=True
    with pytest.raises(RuntimeError,match='Could not confirm GPS restore'):await engine.restore()
    assert engine.active and engine.phase=='error'
    with pytest.raises(RuntimeError):await engine.replace_device(FakePhone())
    assert engine.device is phone
    phone.fail_clear=False;await engine.restore();assert not engine.active
    await engine.close()


@pytest.mark.asyncio
async def test_background_disconnect_stops_playback_and_reports_error():
    engine=Engine(.01);phone=FakePhone();await engine.replace_device(phone)
    await engine.start({'mode':'running','points':[[0,0],[0,.1]]})
    phone.fail_set=True;await asyncio.sleep(.04)
    assert engine.phase=='error' and engine.active and engine.error
    await engine.close()


@pytest.mark.asyncio
async def test_invalid_route_does_not_interrupt_current_session():
    engine=Engine(.01)
    await engine.start({'mode':'stationary','points':[[1,2]]})
    with pytest.raises(ValueError):await engine.start({'mode':'running','points':[[1,2]],'speed':0})
    assert engine.phase=='holding' and engine.position==(1,2)
    await engine.close()


@pytest.mark.asyncio
async def test_shutdown_restores_before_disconnect():
    engine=Engine(.01);phone=FakePhone();await engine.replace_device(phone)
    await engine.start({'mode':'stationary','points':[[1,2]]})
    await engine.close()
    assert phone.calls[-2:]==[('clear',),('close',)]

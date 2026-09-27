import asyncio
from pathlib import Path
import pytest
from routepilot.connection import ConnectionProgress
import routepilot.device as transport


def test_progress_records_actual_step_times_and_freezes_finished_steps():
    now=[10.0];changes=[]
    progress=ConnectionProgress(lambda:changes.append(True),lambda:now[0])
    progress.start();now[0]=12
    progress.step('trust','Trust','Unlock the phone');now[0]=16
    data=progress.snapshot()
    assert data['elapsed']==6 and [s['elapsed'] for s in data['steps']]==[2,4]
    progress.failed('Trust needed',cleaning=True);now[0]=18
    assert progress.snapshot()['active'] and progress.snapshot()['steps'][-1]['elapsed']==4
    progress.failed('Trust needed');now[0]=99
    assert progress.snapshot()['elapsed']==8 and not progress.snapshot()['active']
    assert len(changes)==4


def fake_services(monkeypatch, *, enabled=True, mounted=False, fail_tunnel=False):
    calls=[]
    class Context:
        def __init__(self,*args,**kwargs):pass
        async def __aenter__(self):return self
        async def __aexit__(self,*args):calls.append('closed')
    class Lockdown(Context):
        all_values={'DeviceName':'Test'};product_version='26.6.2'
        async def get_developer_mode_status(self):calls.append('developer');return enabled
    async def usb(**kwargs):calls.append('usb');return Lockdown()
    class Mounter(Context):
        IMAGE_TYPE='Personalized'
        async def is_image_mounted(self,kind):calls.append('image_check');return mounted
        async def mount(self,*paths):calls.append('mount');assert len(paths)==3
    class Tunnel(Context):
        async def __aenter__(self):
            calls.append('tunnel')
            if fail_tunnel:raise ConnectionError('USB connection lost')
            return self
    class Simulation(Context):
        async def set(self,*args):raise AssertionError('Connect must not change location')
    async def prepare():calls.append('download');await asyncio.sleep(0);return (Path('image'),Path('manifest'),Path('trust'))
    services=dict(create_using_usbmux=usb,PersonalizedImageMounter=Mounter,PreferredRsdTunnel=Tunnel,
                  DvtProvider=Context,LocationSimulation=Simulation,AlreadyMountedError=FileExistsError)
    monkeypatch.setattr(transport,'iphone_services',lambda:services)
    monkeypatch.setattr(transport,'prepare_image',prepare)
    return calls


@pytest.mark.asyncio
@pytest.mark.parametrize('mounted',[True,False])
async def test_actual_connection_steps_and_already_mounted_image_fast_path(monkeypatch,mounted):
    calls=fake_services(monkeypatch,mounted=mounted)
    progress=ConnectionProgress();progress.start();phone=transport.IPhoneDevice('fake')
    await phone.open(progress);progress.ready()
    steps=[s['key'] for s in progress.snapshot()['steps']]
    assert steps[:4]==['usb','support','trust','developer']
    assert steps[-3:]==['tunnel','services','location']
    assert ('download' in calls)==(not mounted)
    assert ('image_download' in steps)==(not mounted)
    assert phone.simulation is not None
    await phone.close()


@pytest.mark.asyncio
async def test_disabled_developer_mode_fails_before_downloading(monkeypatch):
    calls=fake_services(monkeypatch,enabled=False)
    progress=ConnectionProgress();progress.start()
    with pytest.raises(RuntimeError,match='Developer Mode'):
        await transport.IPhoneDevice('fake').open(progress)
    assert 'download' not in calls and 'tunnel' not in calls
    data=progress.snapshot()
    assert data['steps'][-1]['key']=='developer' and data['steps'][-1]['status']=='error'
    assert data['status']=='cleaning' and 'Developer Mode' in data['error']


@pytest.mark.asyncio
async def test_tunnel_failure_preserves_failed_stage(monkeypatch):
    calls=fake_services(monkeypatch,fail_tunnel=True)
    progress=ConnectionProgress();progress.start();phone=transport.IPhoneDevice('fake')
    with pytest.raises(ConnectionError):await phone.open(progress)
    assert progress.snapshot()['steps'][-1]['key']=='tunnel'
    assert 'Check the USB cable' in progress.error
    assert phone.stack is None and phone.simulation is None and calls.count('closed')==2


@pytest.mark.asyncio
async def test_image_worker_is_killed_on_cancellation(monkeypatch):
    waiting=asyncio.Event()
    class Process:
        returncode=None;killed=False
        async def communicate(self):
            if self.killed:return b'',b''
            waiting.set();await asyncio.Event().wait()
        def kill(self):self.killed=True;self.returncode=-9
    process=Process()
    async def spawn(*args,**kwargs):return process
    monkeypatch.setattr(asyncio,'create_subprocess_exec',spawn)
    task=asyncio.create_task(transport.prepare_image());await waiting.wait();task.cancel()
    with pytest.raises(asyncio.CancelledError):await task
    assert process.killed


@pytest.mark.asyncio
async def test_image_timeout_is_actionable_and_stops_the_worker(monkeypatch):
    class Process:
        returncode=None
        async def communicate(self):
            if self.returncode is not None:return b'',b''
            await asyncio.Event().wait()
        def kill(self):self.returncode=-9
    process=Process()
    async def spawn(*args,**kwargs):return process
    monkeypatch.setattr(asyncio,'create_subprocess_exec',spawn)
    monkeypatch.setattr(transport,'IMAGE_TIMEOUT',.01)
    with pytest.raises(RuntimeError,match='internet connection'):
        await transport.prepare_image()
    assert process.returncode==-9

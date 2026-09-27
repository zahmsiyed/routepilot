"""Real, persistent pymobiledevice3 transport; no location writes on connect."""
import asyncio
import contextlib
import json
import sys
from contextlib import AsyncExitStack
from pathlib import Path

IMAGE_TIMEOUT = 120


def iphone_services():
    # Imports can be slow on first use. Keep status requests responsive.
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.remote.rsd_tunnel import PreferredRsdTunnel
    from pymobiledevice3.services.mobile_image_mounter import auto_mount, PersonalizedImageMounter
    from pymobiledevice3.exceptions import AlreadyMountedError
    from pymobiledevice3.services.dvt.instruments.dvt_provider import DvtProvider
    from pymobiledevice3.services.dvt.instruments.location_simulation import LocationSimulation
    from pymobiledevice3.services.simulate_location import DtSimulateLocation
    return locals()


async def prepare_image():
    # The library downloads synchronously. A child process keeps the controller
    # responsive and can be stopped when the connection deadline expires.
    code = ('import json; from pymobiledevice3.services.mobile_image_mounter import fetch_personalized_ddi; '
            'print(json.dumps([str(p) for p in fetch_personalized_ddi()]))')
    process = await asyncio.create_subprocess_exec(sys.executable, '-B', '-c', code,
                                                 stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        try:
            stdout, stderr = await asyncio.wait_for(process.communicate(), IMAGE_TIMEOUT)
        except TimeoutError:
            raise RuntimeError('Developer image preparation timed out. Check your internet connection and retry.') from None
        if process.returncode:
            raise RuntimeError('Could not prepare the developer image. Check your internet connection and retry. '
                               + stderr.decode(errors='replace').strip()[-250:])
        paths = json.loads(stdout)
        if not isinstance(paths, list) or len(paths) != 3 or not all(isinstance(p, str) for p in paths):
            raise RuntimeError('Developer image preparation returned an invalid result. Retry the connection.')
        return tuple(Path(p) for p in paths)
    finally:
        if process.returncode is None:
            with contextlib.suppress(ProcessLookupError):
                process.kill()
            await process.communicate()


class PreviewDevice:
    label = 'Preview only'
    kind = 'preview'

    async def set(self, lat, lon):
        pass

    async def clear(self):
        pass

    async def close(self):
        pass


async def list_devices():
    from pymobiledevice3.usbmux import list_devices as usb_devices
    devices = await asyncio.wait_for(usb_devices(), 8)
    return [{'id': d.serial, 'connection': d.connection_type} for d in devices if d.connection_type == 'USB']


class IPhoneDevice:
    kind = 'iphone'

    def __init__(self, serial):
        self.serial = serial
        self.label = 'iPhone'
        self.stack = None
        self.simulation = None

    async def open(self, progress=None):
        report = progress.step if progress else lambda *args: None
        stack = AsyncExitStack()
        try:
            report('support', 'Loading iPhone support', 'Preparing the USB and developer tools on this Mac.')
            services = await asyncio.to_thread(iphone_services)
            report('trust', 'Connecting over USB', 'Keep the iPhone unlocked. Tap Trust This Computer and enter your passcode if asked.')
            lockdown = await stack.enter_async_context(await services['create_using_usbmux'](
                serial=self.serial, connection_type='USB', pair_timeout=15))
            self.label = f"{lockdown.all_values.get('DeviceName', 'iPhone')} · iOS {lockdown.product_version}"
            if progress:
                progress.select_device(self.serial, self.label)
            major = int(lockdown.product_version.split('.')[0])
            if major >= 16:
                report('developer', 'Checking Developer Mode', 'Checking whether developer services are enabled on your iPhone.')
                if not await lockdown.get_developer_mode_status():
                    raise RuntimeError('Enable Developer Mode in iPhone Settings → Privacy & Security, restart, and confirm. Then connect again.')
            report('image_check', 'Checking the developer image', 'Checking whether the iPhone already has its developer image mounted.')
            if major >= 17:
                mounter = await stack.enter_async_context(services['PersonalizedImageMounter'](lockdown=lockdown))
                if not await mounter.is_image_mounted(mounter.IMAGE_TYPE):
                    report('image_download', 'Preparing the developer image', 'Checking the cached image and downloading it if needed. The first connection can take longer; keep internet access available.')
                    paths = await prepare_image()
                    report('image_mount', 'Mounting the developer image', 'Preparing developer services on the iPhone. Apple may need to verify the image over the internet.')
                    with contextlib.suppress(services['AlreadyMountedError']):
                        await mounter.mount(*paths)
                report('tunnel', 'Opening the secure connection', 'Waiting for the iPhone’s developer connection. Keep USB connected and the phone unlocked.')
                rsd = await stack.enter_async_context(services['PreferredRsdTunnel'](serial=self.serial))
                report('services', 'Starting developer services', 'Opening the iPhone’s location-control service.')
                dvt = await stack.enter_async_context(services['DvtProvider'](rsd))
                report('location', 'Preparing location control', 'Checking that the location service is ready. Your location has not been changed.')
                self.simulation = await stack.enter_async_context(services['LocationSimulation'](dvt))
            else:
                with contextlib.suppress(services['AlreadyMountedError']):
                    await services['auto_mount'](lockdown)
                report('location', 'Preparing location control', 'Opening location control. Your location has not been changed.')
                # Legacy service opens a fresh connection on each operation.
                self.simulation = services['DtSimulateLocation'](lockdown)
            self.stack = stack
        except BaseException as exc:
            if progress:
                message = 'The connection timed out or was interrupted. Keep the iPhone unlocked, check USB, and retry.' if isinstance(exc, asyncio.CancelledError) else friendly_error(exc)
                progress.failed(message, cleaning=True)
            self.simulation = None
            with contextlib.suppress(Exception):
                await asyncio.wait_for(stack.aclose(), 15)
            raise
        return self

    async def set(self, lat, lon):
        if self.simulation is None:
            raise RuntimeError('The iPhone connection is closed. Reconnect and restore before continuing.')
        await asyncio.wait_for(self.simulation.set(lat, lon), 8)

    async def clear(self):
        try:
            await asyncio.wait_for(self.simulation.clear(), 8)
        except Exception:
            # USB interruption: rebuild the same device connection and retry clear.
            await self.close()
            await asyncio.wait_for(self.open(), 90)
            await asyncio.wait_for(self.simulation.clear(), 8)

    async def close(self):
        stack, self.stack = self.stack, None
        self.simulation = None
        if stack is not None:
            await asyncio.wait_for(stack.aclose(), 15)


def friendly_error(exc):
    detail = str(exc).strip() or type(exc).__name__
    lower = (type(exc).__name__ + ' ' + detail).lower()
    if 'developermode' in lower or 'developer mode' in lower:
        return 'Enable Developer Mode in iPhone Settings → Privacy & Security, restart, and confirm. Then connect again.'
    if 'pair' in lower or 'trust' in lower or 'password' in lower or 'locked' in lower:
        return 'Unlock your iPhone, tap Trust This Computer, and connect again. ' + detail[:180]
    if 'nodevice' in lower or 'no device' in lower or 'connection' in lower:
        return 'Check the USB cable, unlock your iPhone, and reconnect. ' + detail[:180]
    if isinstance(exc, TimeoutError):
        return 'The iPhone did not respond in time. Unlock it, check Trust and Developer Mode, then retry.'
    return detail[:400]

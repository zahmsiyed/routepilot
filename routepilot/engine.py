"""Serialized playback with monotonic timing, pause, and explicit GPS restore."""
import asyncio
import contextlib
import time
import uuid
from .routes import Route, speed_value
from .device import PreviewDevice, friendly_error
from .motion import SmoothNoise, bounded_value, varied_speed, lateral_position


class Engine:
    def __init__(self, interval=0.5):
        self.revision = 0
        self.session_id = None
        self.checkpoints = []
        self.device = PreviewDevice()
        self.route = None
        self.phase = 'idle'
        self.mode = 'running'
        self.speed = 10.0
        self.speed_variation = 0.0
        self.lateral_variation = 0.0
        self.current_speed = 0.0
        self.lateral_offset = 0.0
        self.speed_noise = SmoothNoise()
        self.lateral_noise = SmoothNoise(period=(8.0, 16.0))
        self.meters = 0.0
        self.elapsed = 0.0
        self.laps = 0
        self.position = None
        self.active = False
        self.error = None
        self.task = None
        self.interval = interval
        self.lock = asyncio.Lock()
        self.last_tick = None

    def snapshot(self):
        total = self.route.total if self.route else 0
        return dict(revision=self.revision, session_id=self.session_id, phase=self.phase, mode=self.mode, speed=self.speed,
                    current_speed=self.current_speed if self.phase == 'playing' else 0.0,
                    speed_variation=self.speed_variation, lateral_variation=self.lateral_variation,
                    lateral_offset=self.lateral_offset,
                    meters=self.meters, total=total, elapsed=self.elapsed,
                    laps=self.laps, position=self.position, active=self.active,
                    device=self.device.kind, label=self.device.label, error=self.error,
                    loop=bool(self.route and self.route.loop),
                    progress=min(1, self.meters / total) if total else 0,
                    remaining=max(0, (total - self.meters) / (self.speed / 3.6)))

    def session(self):
        return {**self.snapshot(), 'points': self.route.points if self.route else [], 'checkpoints': self.checkpoints}

    def touch(self):
        self.revision += 1

    async def cancel(self):
        if self.task is not None:
            task, self.task = self.task, None
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task

    async def _restore(self):
        await self.cancel()
        self.phase = 'restoring'
        self.active = self.active or self.device.kind == 'iphone'
        self.touch()
        try:
            # Clear even if this process has not set a location (recover an old session).
            await self.device.clear()
        except Exception as exc:
            self.phase = 'error'
            self.touch()
            self.error = 'Could not confirm GPS restore. Reconnect USB and retry Restore real location. If that fails, restart your iPhone. ' + friendly_error(exc)
            raise RuntimeError(self.error) from exc
        self.active = False
        self.phase = 'idle'
        self.position = None
        self.current_speed = self.lateral_offset = 0.0
        self.route = None
        self.checkpoints = []
        self.session_id = None
        self.meters = self.elapsed = self.laps = 0
        self.error = None
        self.touch()

    async def restore(self):
        async with self.lock:
            await self._restore()

    async def replace_device(self, device):
        async with self.lock:
            if self.active or self.device.kind == 'iphone':
                await self._restore()
            else:
                await self.cancel()
            await self.device.close()
            self.device = device
            self.phase = 'idle'
            self.error = None
            self.position = None
            self.active = False
            self.touch()

    async def start(self, data):
        mode = data.get('mode', 'running')
        if mode not in ('stationary', 'running', 'driving'):
            raise ValueError('Choose stationary, running, or driving.')
        speed = speed_value(data.get('speed', 10))
        speed_variation = bounded_value(data.get('speed_variation', 0), 50, 'Speed variation (km/h)')
        lateral_variation = bounded_value(data.get('lateral_variation', 0), 2, 'Lateral variation (m)')
        route = Route(data.get('points'), data.get('loop', False) if mode != 'stationary' else False)
        if mode == 'stationary' and len(route.points) != 1:
            raise ValueError('Stationary mode needs exactly one point.')
        if mode != 'stationary' and route.total < 0.01:
            raise ValueError('Add at least two distinct points to move along a route.')
        checkpoints = data.get('checkpoints')
        if checkpoints is not None:
            if not isinstance(checkpoints, list) or len(checkpoints) > 24:
                raise ValueError('Use up to 24 checkpoints.')
            checkpoints = Route(checkpoints).points
        else:
            checkpoints = [route.points[0]] if mode == 'stationary' else [route.points[0], route.points[-1]]
        async with self.lock:
            if self.active:
                raise ValueError('Stop or restore the current session before starting another route.')
            await self.cancel()
            self.route, self.mode, self.speed = route, mode, speed
            self.session_id = uuid.uuid4().hex
            self.checkpoints = checkpoints
            self.speed_variation, self.lateral_variation = speed_variation, lateral_variation
            self.current_speed = speed if mode != 'stationary' else 0.0
            self.lateral_offset = 0.0
            self.speed_noise = SmoothNoise()
            self.lateral_noise = SmoothNoise(period=(8.0, 16.0))
            self.meters = self.elapsed = 0.0
            self.laps = 0
            self.error = None
            self.position = route.points[0]
            self.active = True  # conservative: a failed write may have reached the phone
            self.phase = 'starting'
            self.touch()
            try:
                await self.device.set(*self.position)
            except (Exception, asyncio.CancelledError) as exc:
                self.phase, self.error = 'error', 'Location application was interrupted. Restore real location before continuing.' if isinstance(exc, asyncio.CancelledError) else friendly_error(exc)
                self.touch()
                if isinstance(exc, asyncio.CancelledError):
                    raise
                raise RuntimeError(self.error) from exc
            self.phase = 'holding' if mode == 'stationary' else 'playing'
            self.touch()
            self.last_tick = time.monotonic()
            self.task = asyncio.create_task(self._run())

    async def _run(self):
        try:
            while True:
                await asyncio.sleep(self.interval)
                async with self.lock:
                    now = time.monotonic()
                    # A late write or a sleeping Mac must not cause a large jump.
                    dt = max(0.0, min(now - self.last_tick, 2.0))
                    self.last_tick = now
                    self._advance(dt)
                    # Reapply the held coordinate while paused, detecting a lost USB link.
                    await self.device.set(*self.position)
                # Keep the final location applied until Restore, just like stationary.
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            self.phase, self.error = 'error', friendly_error(exc)
            self.touch()

    def _advance(self, dt):
        """Advance the playback clock and coordinate without performing I/O."""
        if self.phase in ('playing', 'holding'):
            self.elapsed += dt
            self.touch()
        if self.phase == 'playing':
            previous_speed = self.current_speed
            signal = self.speed_noise.advance(dt)
            self.current_speed = varied_speed(self.speed, self.speed_variation, signal)
            self.meters += dt * (previous_speed + self.current_speed) / 7.2
            if self.meters >= self.route.total:
                if self.route.loop:
                    self.laps += int(self.meters // self.route.total)
                    self.meters %= self.route.total
                else:
                    self.meters = self.route.total
                    self.phase = 'completed'
            offset = self.lateral_variation * self.lateral_noise.advance(dt)
            self.position, self.lateral_offset = lateral_position(self.route, self.meters, offset)
            if self.phase == 'completed':
                self.current_speed = 0.0

    async def pause(self, paused=None):
        if paused is not None and not isinstance(paused, bool):
            raise ValueError('Paused must be true or false.')
        async with self.lock:
            if self.phase not in ('playing', 'paused'):
                raise ValueError('Pause and resume are available during route playback.')
            target = not (self.phase == 'paused') if paused is None else paused
            if target != (self.phase == 'paused'):
                self.last_tick = time.monotonic()
                self.phase = 'paused' if target else 'playing'
                self.touch()

    async def set_speed(self, value):
        speed = speed_value(value)
        async with self.lock:
            self.speed = speed
            self.current_speed = varied_speed(speed, self.speed_variation, self.speed_noise.value)
            self.touch()

    async def set_motion(self, data):
        # Validate all values before changing any part of a running session.
        speed = speed_value(data.get('speed', self.speed))
        variation = bounded_value(data.get('speed_variation', self.speed_variation), 50, 'Speed variation (km/h)')
        lateral = bounded_value(data.get('lateral_variation', self.lateral_variation), 2, 'Lateral variation (m)')
        async with self.lock:
            self.speed, self.speed_variation, self.lateral_variation = speed, variation, lateral
            self.current_speed = varied_speed(speed, variation, self.speed_noise.value)
            self.touch()

    async def close(self):
        try:
            await self.restore()
        finally:
            await self.device.close()

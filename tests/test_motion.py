import random
import pytest
from routepilot.motion import SmoothNoise, bounded_value, varied_speed, lateral_position
from routepilot.routes import Route, distance
from routepilot.engine import Engine


def test_noise_is_smooth_bounded_and_reproducible():
    a, b = SmoothNoise(random.Random(23)), SmoothNoise(random.Random(23))
    values = [a.advance(.1) for _ in range(1200)]
    assert values == [b.advance(.1) for _ in range(1200)]
    assert min(values) < -.3 and max(values) > .3
    assert all(-1 <= v <= 1 for v in values)
    assert max(abs(y-x) for x, y in zip(values, values[1:])) < .05
    assert a.advance(0) == values[-1]


@pytest.mark.parametrize('bad', [True, False, None, 'invalid', float('nan'), float('inf'), -1, 2.001])
def test_lateral_setting_rejects_invalid_values(bad):
    with pytest.raises(ValueError):
        bounded_value(bad, 2, 'Lateral variation')


def test_speed_variation_respects_range_and_absolute_limits():
    for base in [.1, 10, 249, 250]:
        for amplitude in [0, 1, 50]:
            for signal in [-2, -1, -.5, 0, .5, 1, 2]:
                speed = varied_speed(base, amplitude, signal)
                assert max(.1, base-amplitude) <= speed <= min(250, base+amplitude)
    assert varied_speed(10, 0, .9) == 10


def test_lateral_offset_is_perpendicular_bounded_and_exact_at_vertices():
    route = Route([[0, 0], [0, .01], [.01, .01]])
    halfway = route.cumulative[1] / 2
    for requested in [-3, -.75, 0, .75, 3]:
        shifted, actual = lateral_position(route, halfway, requested)
        assert abs(actual) <= 2
        assert distance(route.at(halfway), shifted) == pytest.approx(abs(actual), abs=1e-6)
        assert shifted[1] == pytest.approx(route.at(halfway)[1])
    for index, meters in enumerate(route.cumulative):
        position, offset = lateral_position(route, meters, 2)
        assert position == route.points[index] and offset == 0
    # Both sides of a corner approach the same exact coordinate smoothly.
    vertex = route.cumulative[1]
    for delta in [-.001, .001]:
        position, offset = lateral_position(route, vertex+delta, 2)
        assert abs(offset) < .000001
        assert distance(position, route.at(vertex)) < .002


def test_lateral_offset_handles_dateline_and_single_point():
    route = Route([[10, 179.99], [10, -179.99]])
    shifted, offset = lateral_position(route, route.total/2, 2)
    assert -180 <= shifted[1] <= 180
    assert distance(shifted, route.at(route.total/2)) == pytest.approx(2, abs=1e-6)
    assert lateral_position(Route([[12, 34]]), 0, 2) == ((12, 34), 0)


@pytest.mark.asyncio
async def test_engine_integrates_varied_speed_and_pauses_both_variations():
    engine = Engine()
    await engine.start({'mode':'running', 'points':[[0,0],[0,.1]], 'speed':10, 'speed_variation':2, 'lateral_variation':.75})
    await engine.cancel()  # Advance deterministically instead of sleeping for two minutes.
    engine.speed_noise = SmoothNoise(random.Random(4))
    engine.lateral_noise = SmoothNoise(random.Random(9), period=(8,16))
    expected = 0
    observations = []
    for _ in range(240):
        before = engine.current_speed
        engine._advance(.5)
        expected += .5 * (before + engine.current_speed) / 7.2
        assert 8 <= engine.current_speed <= 12
        assert abs(engine.lateral_offset) <= .75
        assert distance(engine.route.at(engine.meters), engine.position) <= .750001
        observations.append((engine.current_speed, engine.lateral_offset))
    assert engine.meters == pytest.approx(expected)
    assert max(v[0] for v in observations)-min(v[0] for v in observations) > 1
    assert max(abs(v[1]) for v in observations) > .2
    await engine.pause()
    frozen = engine.snapshot()
    noise = (engine.speed_noise.value, engine.lateral_noise.value)
    engine._advance(20)
    assert engine.snapshot() == frozen
    assert frozen['current_speed'] == 0
    assert noise == (engine.speed_noise.value, engine.lateral_noise.value)
    await engine.set_motion({'speed':20, 'speed_variation':0, 'lateral_variation':0})
    await engine.pause(); engine._advance(1)
    assert engine.current_speed == 20 and engine.lateral_offset == 0
    assert engine.position == engine.route.at(engine.meters)
    await engine.close()
    assert engine.snapshot()['current_speed'] == engine.snapshot()['lateral_offset'] == 0


@pytest.mark.asyncio
async def test_stationary_and_completed_locations_do_not_drift():
    engine = Engine()
    await engine.start({'mode':'stationary','points':[[12,34]], 'speed_variation':50, 'lateral_variation':2})
    await engine.cancel(); engine._advance(60)
    assert engine.position == (12,34) and engine.snapshot()['current_speed'] == 0
    await engine.restore()
    await engine.start({'mode':'driving','points':[[0,0],[0,.00001]], 'speed':250, 'speed_variation':50, 'lateral_variation':2})
    await engine.cancel(); engine._advance(1)
    assert engine.phase == 'completed' and engine.position == (0,.00001)
    assert engine.current_speed == engine.lateral_offset == 0
    engine._advance(60)
    assert engine.position == (0,.00001)
    await engine.close()


@pytest.mark.asyncio
async def test_invalid_motion_update_preserves_active_session():
    engine = Engine()
    await engine.start({'mode':'running','points':[[0,0],[0,.1]], 'speed':10})
    await engine.cancel()
    before = engine.snapshot()
    with pytest.raises(ValueError):
        await engine.set_motion({'speed':30, 'speed_variation':4, 'lateral_variation':3})
    assert engine.snapshot() == before
    with pytest.raises(ValueError):
        await engine.start({'mode':'stationary','points':[[1,2]], 'speed_variation':-1})
    assert engine.snapshot() == before
    await engine.close()

"""Bounded, smoothly changing motion settings in km/h and metres."""
import bisect
import math
import random
from .routes import EARTH_M, distance


def bounded_value(value, maximum, label):
    try:
        number = float(value)
    except (TypeError, ValueError, OverflowError):
        raise ValueError(f'{label} must be between 0 and {maximum}.') from None
    if isinstance(value, bool) or not math.isfinite(number) or not 0 <= number <= maximum:
        raise ValueError(f'{label} must be between 0 and {maximum}.')
    return number


class SmoothNoise:
    """Cubic interpolation between random targets, with zero slope at each target."""
    def __init__(self, rng=None, period=(6.0, 12.0)):
        self.rng = rng or random.Random()
        self.period = period
        self.value = self.start = 0.0
        self.elapsed = 0.0
        self.target = self.rng.uniform(-1, 1)
        self.duration = self.rng.uniform(*period)

    def advance(self, dt):
        self.elapsed += max(0.0, dt)
        while self.elapsed >= self.duration:
            self.elapsed -= self.duration
            self.start = self.target
            self.target = self.rng.uniform(-1, 1)
            self.duration = self.rng.uniform(*self.period)
        t = self.elapsed / self.duration
        weight = t * t * (3 - 2 * t)
        self.value = self.start + (self.target - self.start) * weight
        return self.value


def varied_speed(base, amplitude, signal):
    return max(0.1, min(250.0, base + amplitude * max(-1.0, min(1.0, signal))))


def lateral_position(route, meters, requested_offset):
    """Offset perpendicular to the route, fading to zero at vertices/endpoints.

    The signed offset is at most 2 m. This represents small coordinate drift;
    it does not determine road width or guarantee containment in a mapped lane.
    """
    center = route.at(meters)
    if not requested_offset or route.total == 0 or meters <= 0 or meters >= route.total:
        return center, 0.0
    i = min(bisect.bisect_right(route.cumulative, meters)-1, len(route.points)-2)
    nearby_vertex = min(meters-route.cumulative[i], route.cumulative[i+1]-meters)
    t = min(1.0, max(0.0, nearby_vertex / 5.0))
    offset = max(-2.0, min(2.0, requested_offset)) * t*t*(3-2*t)
    if offset == 0:
        return center, 0.0
    a, b = route.points[i], route.points[i+1]
    if distance(a, b) < .001:
        return center, 0.0
    lat1, lon1, lat2, lon2 = map(math.radians, (*center, *b))
    dl = lon2 - lon1
    heading = math.atan2(math.sin(dl)*math.cos(lat2), math.cos(lat1)*math.sin(lat2)-math.sin(lat1)*math.cos(lat2)*math.cos(dl))
    bearing = heading + math.pi/2
    lat, lon = map(math.radians, center)
    angular = offset / EARTH_M
    shifted_lat = math.asin(max(-1, min(1, math.sin(lat)*math.cos(angular)+math.cos(lat)*math.sin(angular)*math.cos(bearing))))
    shifted_lon = lon + math.atan2(math.sin(bearing)*math.sin(angular)*math.cos(lat), math.cos(angular)-math.sin(lat)*math.sin(shifted_lat))
    return (math.degrees(shifted_lat), (math.degrees(shifted_lon)+180)%360-180), offset

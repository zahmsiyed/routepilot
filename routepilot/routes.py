"""Validated routes, geodesic interpolation, and portable GPX files."""
import bisect
import math
from datetime import datetime, timedelta, timezone
from xml.etree import ElementTree as ET
from defusedxml.ElementTree import fromstring

EARTH_M = 6_371_008.8
MAX_POINTS = 30_000


def coordinate(value):
    if not isinstance(value, (list, tuple)) or len(value) != 2:
        raise ValueError("Each point needs latitude and longitude.")
    if any(isinstance(v, bool) for v in value):
        raise ValueError("Coordinates must be numbers.")
    try:
        lat, lon = map(float, value)
    except (TypeError, ValueError, OverflowError):
        raise ValueError("Coordinates must be numbers.") from None
    if not math.isfinite(lat) or not math.isfinite(lon) or not -90 <= lat <= 90 or not -180 <= lon <= 180:
        raise ValueError("Latitude must be −90 to 90 and longitude −180 to 180.")
    return (lat, lon)


def speed_value(value):
    try:
        speed = float(value)
    except (TypeError, ValueError, OverflowError):
        raise ValueError("Enter a speed between 0.1 and 250 km/h.") from None
    if isinstance(value, bool) or not math.isfinite(speed) or not 0.1 <= speed <= 250:
        raise ValueError("Enter a speed between 0.1 and 250 km/h.")
    return speed


def distance(a, b):
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dp, dl = p2 - p1, math.radians(b[1] - a[1])
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * EARTH_M * math.asin(math.sqrt(max(0, min(1, h))))


def interpolate(a, b, fraction):
    if fraction <= 0:
        return a
    if fraction >= 1:
        return b
    angular = distance(a, b) / EARTH_M
    if angular < 1e-10:
        return a
    if angular > math.pi - 1e-6:
        raise ValueError("Add an intermediate point between opposite sides of the globe.")
    x = math.sin((1 - fraction) * angular) / math.sin(angular)
    y = math.sin(fraction * angular) / math.sin(angular)
    p1, l1, p2, l2 = map(math.radians, (*a, *b))
    vx = x * math.cos(p1) * math.cos(l1) + y * math.cos(p2) * math.cos(l2)
    vy = x * math.cos(p1) * math.sin(l1) + y * math.cos(p2) * math.sin(l2)
    vz = x * math.sin(p1) + y * math.sin(p2)
    return math.degrees(math.atan2(vz, math.hypot(vx, vy))), math.degrees(math.atan2(vy, vx))


class Route:
    def __init__(self, points, loop=False):
        if not isinstance(points, list) or not 1 <= len(points) <= MAX_POINTS:
            raise ValueError(f"Choose 1 to {MAX_POINTS:,} route points.")
        self.points = []
        for raw in points:
            point = coordinate(raw)
            if not self.points or distance(self.points[-1], point) > 0.001:
                self.points.append(point)
        if not isinstance(loop, bool):
            raise ValueError('Loop must be true or false.')
        self.loop = loop
        if self.loop and len(self.points) > 1 and distance(self.points[-1], self.points[0]) > 0.001:
            if len(self.points) >= MAX_POINTS:
                raise ValueError('Leave room for the return point when looping a maximum-sized route.')
            self.points.append(self.points[0])
        self.cumulative = [0.0]
        for a, b in zip(self.points, self.points[1:]):
            length = distance(a, b)
            if length / EARTH_M > math.pi - 1e-6:
                raise ValueError("Add an intermediate point between opposite sides of the globe.")
            self.cumulative.append(self.cumulative[-1] + length)
        self.total = self.cumulative[-1]

    def at(self, meters):
        if self.total == 0 or meters <= 0:
            return self.points[0]
        if meters >= self.total:
            return self.points[-1]
        i = min(bisect.bisect_right(self.cumulative, meters) - 1, len(self.points) - 2)
        fraction = (meters - self.cumulative[i]) / (self.cumulative[i + 1] - self.cumulative[i])
        return interpolate(self.points[i], self.points[i + 1], fraction)


def parse_gpx(xml):
    try:
        root = fromstring(xml)
        if root.tag.split('}')[-1] != 'gpx':
            raise ValueError("Choose a GPX document.")
        # Prefer a track, then a route, then Xcode waypoints. Never concatenate
        # disconnected tracks/segments: doing so would invent a jump.
        segments = [e for e in root.iter() if e.tag.split('}')[-1] == 'trkseg' and any(child.tag.split('}')[-1] == 'trkpt' for child in e)]
        routes = [e for e in root.iter() if e.tag.split('}')[-1] == 'rte']
        if len(segments) > 1 or (not segments and len(routes) > 1):
            raise ValueError("Import one continuous track segment or route at a time.")
        container = segments[0] if segments else (routes[0] if routes else root)
        tag = 'trkpt' if segments else ('rtept' if routes else 'wpt')
        points = [coordinate([e.attrib.get('lat'), e.attrib.get('lon')]) for e in container
                  if e.tag.split('}')[-1] == tag]
        return Route(points).points
    except ValueError:
        raise
    except Exception as exc:
        raise ValueError("That GPX file is malformed or contains unsafe XML.") from exc


def export_gpx(route, speed, name='RoutePilot route'):
    speed = speed_value(speed)
    duration = route.total / (speed / 3.6)
    # Bound file size while retaining corners and timed samples along long legs.
    if duration > 365 * 86400:
        raise ValueError('This GPX would run longer than a year. Use a shorter route or higher speed.')
    sample_budget = max(0, MAX_POINTS - len(route.points) - 2)
    interval = max(1.0, duration / max(1, min(20_000, sample_budget)))
    times = {0.0, duration}
    times.update(d / (speed / 3.6) for d in route.cumulative)
    if sample_budget:
        times.update(i * interval for i in range(int(duration / interval) + 1))
    start = datetime.now(timezone.utc)
    root = ET.Element('gpx', version='1.1', creator='RoutePilot', xmlns='http://www.topografix.com/GPX/1/1')
    metadata = ET.SubElement(root, 'metadata')
    ET.SubElement(metadata, 'name').text = str(name)[:100]
    samples_by_time = {t: route.at(t * speed / 3.6) for t in sorted(times)}
    for point, meters in zip(route.points, route.cumulative):
        samples_by_time[meters / (speed / 3.6)] = point
    samples = sorted(samples_by_time.items())
    def add(parent, tag, t, p):
        node = ET.SubElement(parent, tag, lat=f'{p[0]:.8f}', lon=f'{p[1]:.8f}')
        ET.SubElement(node, 'time').text = (start + timedelta(seconds=t)).isoformat(timespec='milliseconds').replace('+00:00', 'Z')
    # Xcode consumes wpt; common GPS tools consume trkpt. Import prefers trkpt.
    for t, point in samples:
        add(root, 'wpt', t, point)
    track = ET.SubElement(root, 'trk')
    ET.SubElement(track, 'name').text = str(name)[:100]
    segment = ET.SubElement(track, 'trkseg')
    for t, point in samples:
        add(segment, 'trkpt', t, point)
    return ET.tostring(root, encoding='utf-8', xml_declaration=True)

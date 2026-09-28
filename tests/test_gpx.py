from datetime import datetime
from xml.etree import ElementTree as ET
import pytest
from routepilot.gpx import create_gpx
from routepilot.routes import Route, parse_gpx, MAX_POINTS

NS = {'g': 'http://www.topografix.com/GPX/1/1'}
DATA = dict(points=[[37, -122], [37.0005, -122], [37.0005, -121.999]], mode='running', format='activity', speed=12, start_time='2026-09-27T08:30:00-07:00', name='Test <run> & route')


def test_activity_is_one_timestamped_track_with_utc_corners_and_duration():
    xml = create_gpx(DATA)
    root = ET.fromstring(xml)
    assert root.find('g:metadata/g:name', NS).text == DATA['name']
    assert 'Simulated' in root.find('g:metadata/g:desc', NS).text
    assert root.find('g:wpt', NS) is None
    assert root.find('g:rte', NS) is None
    assert len(root.findall('g:trk/g:trkseg', NS)) == 1
    track = root.findall('g:trk/g:trkseg/g:trkpt', NS)
    times = [datetime.fromisoformat(p.find('g:time', NS).text) for p in track]
    assert times[0].isoformat() == '2026-09-27T15:30:00+00:00'
    assert all(b > a for a, b in zip(times, times[1:]))
    assert (times[-1]-times[0]).total_seconds() == pytest.approx(Route(DATA['points']).total/(12/3.6), abs=.000001)
    points = parse_gpx(xml)
    assert all(tuple(point) in points for point in DATA['points'])
    assert not root.findall('.//g:ele', NS)


def test_route_has_no_timing_and_ignores_irrelevant_timing_fields():
    root = ET.fromstring(create_gpx({**DATA, 'format': 'route', 'start_time': 'bad', 'speed': None}))
    assert not root.findall('.//g:time', NS)
    assert len(root.findall('g:rte/g:rtept', NS)) == 3
    assert root.find('g:trk', NS) is None


def test_stationary_only_allows_route_or_xcode_and_loop_exports_once():
    stationary = {**DATA, 'mode': 'stationary', 'points': [[10, 20]]}
    with pytest.raises(ValueError, match='moving route'):
        create_gpx(stationary)
    for format_ in ('route', 'xcode'):
        xml = create_gpx({**stationary, 'format': format_})
        assert parse_gpx(xml) == [(10, 20)]
    root = ET.fromstring(create_gpx({**DATA, 'format': 'xcode', 'loop': True}))
    assert root.find('g:trk', NS) is None
    assert len(root.findall('g:wpt', NS)) > 3
    points = parse_gpx(ET.tostring(root))
    assert points[0] == points[-1] == tuple(DATA['points'][0])


@pytest.mark.parametrize('override', [
    {'start_time': None}, {'start_time': '2026-09-27T08:30:00'}, {'start_time': 'bad'},
    {'start_time': '1969-12-31T23:59:59Z'}, {'name': ''}, {'name': 'a'*101},
    {'name': '\x00'}, {'name': '\ud800'}, {'format': 'fit'}, {'mode': 'virtual_run'},
    {'speed': float('nan')}, {'speed': True}, {'speed': 0},
])
def test_invalid_creator_inputs(override):
    with pytest.raises(ValueError):
        create_gpx({**DATA, **override})


def test_tiny_legs_keep_unique_timestamps_and_full_routes_stay_bounded():
    points = [[0, i*.00000002] for i in range(MAX_POINTS)]
    root = ET.fromstring(create_gpx({**DATA, 'points': points, 'speed': 250}))
    track = root.findall('g:trk/g:trkseg/g:trkpt', NS)
    assert len(track) == MAX_POINTS
    times = [p.find('g:time', NS).text for p in track]
    assert all(b > a for a, b in zip(times, times[1:]))
    long_file = create_gpx({**DATA, 'points': [[0, 0], [0, 90]], 'speed': 10})
    assert len(ET.fromstring(long_file).findall('.//g:trkpt', NS)) <= MAX_POINTS
    assert len(long_file) < 4_000_000


def test_unsupported_date_and_excessive_duration_are_actionable():
    with pytest.raises(ValueError, match='start date'):
        create_gpx({**DATA, 'start_time': '9999-12-31T23:59:59Z'})
    with pytest.raises(ValueError, match='longer than a year'):
        create_gpx({**DATA, 'points': [[0, 0], [0, 90]], 'speed': .1})


def test_old_api_shape_keeps_legacy_export():
    root = ET.fromstring(create_gpx({'points': DATA['points'], 'speed': 10}))
    assert root.find('g:wpt', NS) is not None
    assert root.find('g:trk', NS) is not None

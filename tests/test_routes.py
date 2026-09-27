import math
from xml.etree import ElementTree as ET
import pytest
from routepilot.routes import Route, coordinate, distance, export_gpx, parse_gpx, speed_value


def test_distance_and_speed_duration():
    route = Route([[0,0],[0,0.01]])
    assert route.total == pytest.approx(1111.95, abs=.1)
    assert route.total / (36/3.6) == pytest.approx(111.195, abs=.01)
    assert route.at(route.total/2) == pytest.approx((0,.005))
    assert route.at(route.total+1) == (0,.01)


def test_loop_closes_continuously_and_removes_duplicates():
    route = Route([[0,0],[0,0],[0,.01]],loop=True)
    assert route.points == [(0,0),(0,.01),(0,0)]
    assert route.at(route.total*.75) == pytest.approx((0,.005))
    assert route.at(route.total) == route.at(0)


def test_dateline_uses_short_arc():
    route=Route([[0,179.9],[0,-179.9]])
    assert route.total < 23_000
    assert abs(route.at(route.total/2)[1]) == pytest.approx(180)


@pytest.mark.parametrize('point', [[91,0],[0,181],[math.nan,0],[0,math.inf],['bad',0],[True,0],[],None])
def test_invalid_coordinates(point):
    with pytest.raises(ValueError):coordinate(point)


@pytest.mark.parametrize('speed', [0,-1,251,math.inf,math.nan,'bad',None,True])
def test_invalid_speed(speed):
    with pytest.raises(ValueError):speed_value(speed)


def test_antipodes_rejected():
    with pytest.raises(ValueError):Route([[0,0],[0,180]])


def test_gpx_roundtrip_preserves_geometry_and_timing():
    route = Route([[37.77,-122.49],[37.771,-122.489],[37.77,-122.488]])
    exported = export_gpx(route,36,'A < B & C')
    points = parse_gpx(exported)
    assert points[0] == pytest.approx(route.points[0])
    assert points[-1] == pytest.approx(route.points[-1])
    assert len(points)>3
    root=ET.fromstring(exported)
    ns={'g':'http://www.topografix.com/GPX/1/1'}
    track=root.findall('g:trk/g:trkseg/g:trkpt',ns)
    assert len(track)==len(root.findall('g:wpt',ns))
    from datetime import datetime
    times=[datetime.fromisoformat(p.find('g:time',ns).text) for p in track]
    assert times == sorted(times)
    assert (times[-1]-times[0]).total_seconds()==pytest.approx(route.total/10,abs=.002)


@pytest.mark.parametrize('tag',['wpt','rtept','trkpt'])
def test_gpx_variants(tag):
    node=f'<{tag} lat="1" lon="2"/>'
    if tag=='rtept':node='<rte>'+node+'</rte>'
    if tag=='trkpt':node='<trk><trkseg>'+node+'</trkseg></trk>'
    assert parse_gpx('<gpx>'+node+'</gpx>')==[(1.,2.)]


def test_gpx_multisegment_does_not_invent_a_jump():
    xml='<gpx><trk><trkseg><trkpt lat="1" lon="2"/></trkseg><trkseg><trkpt lat="3" lon="4"/></trkseg></trk></gpx>'
    with pytest.raises(ValueError,match='one continuous'):parse_gpx(xml)


def test_gpx_rejects_xml_entities():
    with pytest.raises(ValueError):parse_gpx('<!DOCTYPE gpx [<!ENTITY x SYSTEM "file:///etc/passwd">]><gpx>&x;</gpx>')

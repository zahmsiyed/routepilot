import asyncio
import json
import time
import pytest
from aiohttp import web
from aiohttp.test_utils import TestServer
from routepilot.geocoding import Geocoder, parse_places, search_query


def feature(name='Park', point=None, **properties):
    return {'type':'Feature','geometry':{'type':'Point','coordinates':point or [-122.48,37.77]},
            'properties':{'name':name,'city':'San Francisco','state':'California','country':'United States',**properties}}


def response(*features):
    return json.dumps({'type':'FeatureCollection','features':list(features)})


@pytest.mark.parametrize('query',[None,{},'', ' ', 'x', 'x'*201])
def test_invalid_queries_are_rejected(query):
    with pytest.raises(ValueError):search_query(query)


def test_places_have_safe_coordinates_address_and_bounds():
    results=parse_places(response(feature(extent=[-122.50,37.78,-122.46,37.76]),feature(),feature('Library',[-122.45,37.75])))
    assert len(results)==2
    assert results[0]['point']==(37.77,-122.48)
    assert results[0]['bounds']==[(37.76,-122.50),(37.78,-122.46)]
    assert results[0]['description']=='San Francisco, California, United States'
    assert search_query(' Golden  Gate\nPark ')=='Golden Gate Park'


@pytest.mark.parametrize('raw',['bad JSON','{}','[]',response(feature(point=[1,91])),response(feature(point=[True,2])),response(feature(point=[float('nan'),2]))])
def test_bad_provider_responses_are_explained(raw):
    with pytest.raises(ValueError):parse_places(raw)


def test_empty_results_malformed_entries_and_invalid_bounds():
    assert parse_places(response())==[]
    places=parse_places(response(None,feature(extent=[0,1,2,3]),feature('Library',[-122.45,37.75])))
    assert len(places)==2 and places[0]['bounds'] is None
    assert len(parse_places(response(*[feature(str(n)) for n in range(10)])))==5


@pytest.mark.asyncio
async def test_cache_and_rate_limit_apply_across_concurrent_searches():
    calls=[]
    async def handler(request):
        calls.append((time.monotonic(),dict(request.query),request.headers['User-Agent']))
        return web.Response(text=response(feature()),content_type='application/json')
    app=web.Application();app.router.add_get('/api/',handler)
    async with TestServer(app) as provider:
        geocoder=Geocoder(str(provider.make_url('/api/')),interval=.04)
        first,second=await asyncio.gather(geocoder.search('Golden Gate Park'),geocoder.search(' golden  gate park '))
        assert first==second and len(calls)==1
        await geocoder.search('Another park')
        assert calls[1][0]-calls[0][0]>=.03
        assert calls[0][1]=={'q':'Golden Gate Park','limit':'5','lang':'en'}
        assert calls[0][2].startswith('RoutePilot/')


@pytest.mark.asyncio
@pytest.mark.parametrize('status,payload,expected',[(429,'','busy'),(503,'','unavailable'),(200,'<html>error</html>','invalid response'),(200,'x'*1_000_001,'too large')])
async def test_provider_failures_are_not_cached_and_can_recover(status,payload,expected):
    mode=[status,payload]
    async def handler(request):return web.Response(status=mode[0],text=mode[1])
    app=web.Application();app.router.add_get('/api/',handler)
    async with TestServer(app) as provider:
        geocoder=Geocoder(str(provider.make_url('/api/')),interval=0)
        with pytest.raises(ValueError,match=expected):await geocoder.search('Park')
        assert not geocoder.cache
        mode[:]=[200,response()]
        assert await geocoder.search('Park')==[]

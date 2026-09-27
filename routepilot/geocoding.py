"""Bounded, cached place search through a configurable Photon endpoint."""
import asyncio
import json
import os
import time
from collections import OrderedDict
from aiohttp import ClientError, ClientSession, ClientTimeout
from .routes import coordinate

MAX_BYTES = 1_000_000


def search_query(value):
    if not isinstance(value, str):
        raise ValueError('Enter a place name or address.')
    query = ' '.join(value.split())
    if not 2 <= len(query) <= 200:
        raise ValueError('Use 2–200 characters for a place name or address.')
    return query


def parse_places(raw):
    try:
        data = json.loads(raw)
    except (ValueError, UnicodeError):
        raise ValueError('The search service returned an invalid response. Try again.') from None
    features = data.get('features') if isinstance(data, dict) else None
    if not isinstance(features, list) or len(features) > 100:
        raise ValueError('The search service returned an invalid response. Try again.')
    results, seen = [], set()
    for feature in features:
        if not isinstance(feature, dict):
            continue
        geometry, props = feature.get('geometry'), feature.get('properties')
        if not isinstance(geometry, dict) or geometry.get('type') != 'Point' or not isinstance(props, dict):
            continue
        try:
            lon, lat = geometry['coordinates']
            if isinstance(lon, bool) or isinstance(lat, bool):
                continue
            point = coordinate([lat, lon])
        except (KeyError, ValueError, TypeError, OverflowError):
            continue
        def part(key):
            value = props.get(key)
            return ' '.join(value.split())[:200] if isinstance(value, str) else ''
        street = ' '.join(filter(None, [part('housenumber'), part('street')]))
        name = part('name') or street or part('city') or part('state') or part('country')
        if not name:
            continue
        address = []
        for piece in [street, part('district'), part('city'), part('state'), part('postcode'), part('country')]:
            if piece and piece.casefold() != name.casefold() and piece not in address:
                address.append(piece)
        key = (name.casefold(), *point)
        if key in seen:
            continue
        seen.add(key)
        result = dict(name=name, description=', '.join(address)[:600], point=point, bounds=None)
        extent = props.get('extent')
        if isinstance(extent, list) and len(extent) == 4:
            try:
                west, north, east, south = extent
                sw, ne = coordinate([south, west]), coordinate([north, east])
                if sw[0] <= point[0] <= ne[0] and sw[1] <= point[1] <= ne[1]:
                    result['bounds'] = [sw, ne]
            except (ValueError, TypeError, OverflowError):
                pass
        results.append(result)
        if len(results) == 5:
            break
    if features and not results:
        raise ValueError('The search service returned no usable locations. Try again.')
    return results


class Geocoder:
    def __init__(self, endpoint=None, interval=1.1):
        self.endpoint = endpoint or os.environ.get('ROUTEPILOT_GEOCODER_URL', 'https://photon.komoot.io/api/')
        self.lock = asyncio.Lock()
        self.last_request = -float('inf')
        self.interval = interval
        self.cache = OrderedDict()

    async def search(self, value):
        query = search_query(value)
        try:
            return await asyncio.wait_for(self._search(query), 25)
        except TimeoutError:
            raise ValueError('Location search timed out. Check your internet connection and try again.') from None
        except ClientError:
            raise ValueError('Could not reach location search. Check your internet connection and try again.') from None

    async def _search(self, query):
        # Separate from playback/connection locks; concurrent duplicate searches share the cache.
        async with self.lock:
            key, now = query.casefold(), time.monotonic()
            if key in self.cache and now - self.cache[key][0] < 86400:
                self.cache.move_to_end(key)
                return self.cache[key][1]
            delay = self.interval - (now - self.last_request)
            if delay > 0:
                await asyncio.sleep(delay)
            self.last_request = time.monotonic()
            async with ClientSession(timeout=ClientTimeout(total=20), headers={'User-Agent': 'RoutePilot/1.0 (local personal route planner)'}) as client:
                async with client.get(self.endpoint, params={'q': query, 'limit': 5, 'lang': 'en'}) as response:
                    if response.status == 429:
                        raise ValueError('Location search is busy. Wait a moment, then try again.')
                    if response.status != 200:
                        raise ValueError('Location search is unavailable. Try again in a moment.')
                    raw = bytearray()
                    async for chunk in response.content.iter_chunked(65536):
                        raw.extend(chunk)
                        if len(raw) > MAX_BYTES:
                            raise ValueError('The search response is too large. Try a more specific address.')
            results = parse_places(raw)
            self.cache[key] = (time.monotonic(), results)
            self.cache.move_to_end(key)
            while len(self.cache) > 128:
                self.cache.popitem(last=False)
            return results

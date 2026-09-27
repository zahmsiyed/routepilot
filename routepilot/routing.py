"""Defensive parsing for the external routing service."""
import json
from .routes import Route, MAX_POINTS

MAX_RESPONSE_BYTES = 4_000_000


def parse_route_response(raw):
    if len(raw) > MAX_RESPONSE_BYTES:
        raise ValueError('The routing response is too large. Use fewer or closer checkpoints.')
    try:
        result = json.loads(raw)
        if not isinstance(result, dict) or result.get('code') != 'Ok':
            raise ValueError('No route found on nearby roads or paths. Move a checkpoint and retry.')
        routes = result.get('routes')
        if not isinstance(routes, list) or not routes or not isinstance(routes[0], dict):
            raise TypeError()
        geometry = routes[0].get('geometry')
        if not isinstance(geometry, dict) or geometry.get('type') != 'LineString':
            raise TypeError()
        coordinates = geometry.get('coordinates')
        if not isinstance(coordinates, list) or not 2 <= len(coordinates) <= MAX_POINTS:
            raise TypeError()
        if any(not isinstance(p, list) or len(p) < 2 for p in coordinates):
            raise TypeError()
        route = Route([[p[1], p[0]] for p in coordinates])
        if route.total < .01:
            raise ValueError('The checkpoints resolve to the same location. Move a checkpoint farther away.')
        return route
    except (TypeError, KeyError, IndexError, json.JSONDecodeError, UnicodeDecodeError):
        raise ValueError('The routing service returned an invalid route. Retry in a moment.') from None

import importlib.util
import http.client
import json
from pathlib import Path
import sys
import threading
import unittest
from http.server import ThreadingHTTPServer
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen

CLOUD = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(CLOUD))
spec = importlib.util.spec_from_file_location('cloud_api', CLOUD / 'api/index.py')
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)


class HostedAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(('127.0.0.1', 0), api.handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f'http://127.0.0.1:{cls.server.server_port}'

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def post(self, path, value, **headers):
        request = Request(self.base + path, data=json.dumps(value).encode(), headers={'Content-Type': 'application/json', **headers})
        try:
            response = urlopen(request)
        except HTTPError as error:
            response = error
        with response:
            return response.status, response.read()

    def test_profile_and_rewrite(self):
        for mode, profile in [('running', 'foot'), ('driving', 'car')]:
            with patch.object(api, 'remote', return_value=api.Route([[1, 1], [1, 2]])) as remote:
                code, body = self.post('/api/index?action=route', {'points': [[1, 1], [1, 2]], 'mode': mode})
                self.assertEqual(code, 200)
                self.assertEqual(json.loads(body)['profile'], profile)
                self.assertIn(f'routed-{profile}/', remote.call_args.args[1])

    def test_reject_device_and_bad_inputs(self):
        for path, value in [('/api/connect', {}), ('/api/status', {}), ('/api/route', {'points': [[91, 0], [0, 0]], 'mode': 'running'}), ('/api/import', {'gpx': '<bad>'}), ('/api/search', {'query': 'a'}), ('/api/search', []), ('/api/export', {'points': [[0, 0]], 'speed': float('nan')})]:
            code, body = self.post(path, value)
            self.assertIn(code, (400, 404))
            self.assertIn('error', json.loads(body))

    def test_origin_and_body_limit(self):
        self.assertEqual(self.post('/api/search', {'query': 'Paris'}, Origin='https://other.example')[0], 403)
        # Reject from headers before accepting a large upload. Sending megabytes
        # here races the deliberate early connection close on the local server.
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port)
        connection.request('POST', '/api/import', headers={'Content-Type': 'application/json', 'Content-Length': '4000001'})
        response = connection.getresponse()
        self.assertEqual(response.status, 413)
        response.read()
        connection.close()

    def test_gpx_roundtrip(self):
        status, gpx = self.post('/api/export', {'points': [[37, -122], [37.0001, -122]], 'speed': 10})
        self.assertEqual(status, 200)
        status, body = self.post('/api/import', {'gpx': gpx.decode()})
        self.assertEqual(status, 200)
        points = json.loads(body)['points']
        self.assertEqual(points[0], [37, -122])
        self.assertEqual(points[-1], [37.0001, -122])

    def test_search_schema(self):
        result = [{'name': 'Paris', 'description': 'France', 'point': [48.85, 2.35], 'bounds': None}]
        with patch.object(api, 'remote', return_value=result):
            code, body = self.post('/api/search', {'query': 'Paris France'})
            self.assertEqual(code, 200)
            self.assertEqual(json.loads(body)['results'], result)


if __name__ == '__main__':
    unittest.main()

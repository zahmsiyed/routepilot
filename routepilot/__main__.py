import argparse
import asyncio
import logging
import errno
import json
import re
import urllib.request
import webbrowser
from aiohttp import web
from .server import create_app


def existing_controller(url):
    """Only reuse a port after a successful RoutePilot status handshake."""
    try:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(url, timeout=2) as response:
            html = response.read(32768).decode('utf-8')
        match = re.search(r'name="routepilot-token" content="([^"]+)"', html)
        if not match:
            return False
        request = urllib.request.Request(url + '/api/status', headers={'X-RoutePilot-Token': match[1]})
        with opener.open(request, timeout=2) as response:
            status = json.loads(response.read(32768))
        return isinstance(status, dict) and isinstance(status.get('active'), bool) and status.get('device') in ('preview', 'iphone')
    except (OSError, ValueError):
        return False


def main():
    parser = argparse.ArgumentParser(description='RoutePilot local iPhone location controller')
    parser.add_argument('--port', type=int, default=8765)
    parser.add_argument('--open', action='store_true', help='Open the controller in your browser')
    parser.add_argument('--no-open', action='store_false', dest='open', help='Keep the controller headless')
    parser.set_defaults(open=False)
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error('Use a port between 1024 and 65535.')
    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
    async def run():
        runner = web.AppRunner(create_app(args.port), access_log=None)
        await runner.setup()
        try:
            await web.TCPSite(runner, '127.0.0.1', args.port).start()
            url = f'http://127.0.0.1:{args.port}'
            print(f'\nRoutePilot is ready at {url}\nKeep this window open. Control-C stops the app and attempts GPS restore.\n', flush=True)
            if args.open:
                webbrowser.open(url)
            await asyncio.Event().wait()
        finally:
            await runner.cleanup()
    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        pass
    except OSError as exc:
        url = f'http://127.0.0.1:{args.port}'
        if exc.errno == errno.EADDRINUSE and existing_controller(url):
            print(f'RoutePilot is already running at {url}', flush=True)
            if args.open:
                webbrowser.open(url)
            return
        parser.exit(1, f'Could not start RoutePilot: {exc}\nIf it is already running, open http://127.0.0.1:{args.port}\n')


if __name__ == '__main__':
    main()

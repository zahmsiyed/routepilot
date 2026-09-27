"""Launch from a local cache, keeping dependency and bytecode files out of synced folders."""
import fcntl
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time


def prepare_source(root, cache):
    package = root / 'routepilot'
    files = sorted(p for p in package.rglob('*') if p.is_file() and '__pycache__' not in p.parts and not p.name.endswith('.pyc'))
    digest = hashlib.sha256()
    payload = []
    for path in files:
        relative, content = path.relative_to(package), path.read_bytes()
        digest.update(str(relative).encode() + b'\0' + content + b'\0')
        payload.append((relative, content))
    destination = cache / ('app-' + digest.hexdigest()[:20])
    if destination.is_dir():
        return destination
    with tempfile.TemporaryDirectory(prefix='app-staging-', dir=cache) as folder:
        staging = Path(folder) / 'app'
        for relative, content in payload:
            target = staging / 'routepilot' / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
        staging.rename(destination)
    return destination


def main():
    root = Path(__file__).resolve().parent
    cache = Path(os.environ.get('ROUTEPILOT_CACHE_DIR', str(Path.home() / 'Library' / 'Caches' / 'RoutePilot'))).expanduser()
    cache.mkdir(parents=True, exist_ok=True)
    requirements = root / 'requirements.txt'
    signature = hashlib.sha256(requirements.read_bytes()).hexdigest()[:16]
    runtime = cache / f'python-{sys.version_info.major}.{sys.version_info.minor}-{signature}'
    python = runtime / 'bin' / 'python'
    ready = runtime / '.ready'
    uv = shutil.which('uv')
    with (cache / 'setup.lock').open('a') as lock:
        deadline = time.monotonic() + 180
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise RuntimeError('Another RoutePilot setup is still running. Try again after it finishes.')
                time.sleep(.25)
        if not python.exists():
            command = [uv, 'venv', '--python', sys.executable, str(runtime)] if uv else [sys.executable, '-m', 'venv', str(runtime)]
            subprocess.run(command, check=True, timeout=120)
        def healthy():
            try:
                result = subprocess.run([str(python), '-B', '-c', 'from aiohttp import web; import defusedxml, pymobiledevice3'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=25)
                return result.returncode == 0
            except subprocess.TimeoutExpired:
                return False
        if not ready.exists() or not healthy():
            ready.unlink(missing_ok=True)
            print('Preparing RoutePilot dependencies in the local cache…', flush=True)
            command = [uv, 'pip', 'install', '--link-mode', 'copy', '--python', str(python), '--reinstall', '-r', str(requirements)] if uv else [str(python), '-m', 'pip', 'install', '--force-reinstall', '-r', str(requirements)]
            subprocess.run(command, check=True, timeout=600)
            if not healthy():
                raise RuntimeError('Dependency loading failed. Run the launcher again to repair the installation.')
            ready.touch()
        app = prepare_source(root, cache)
    os.environ['PYTHONPYCACHEPREFIX'] = str(cache / 'bytecode')
    os.chdir(app)
    os.execv(str(python), [str(python), '-B', '-m', 'routepilot', '--open', *sys.argv[1:]])


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        print(f'RoutePilot could not launch: {exc}\nRun the launcher again after resolving the error.', file=sys.stderr)
        sys.exit(1)

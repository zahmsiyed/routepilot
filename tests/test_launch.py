from pathlib import Path
from launch import prepare_source


def test_cached_source_is_complete_isolated_and_refreshes_after_edits(tmp_path):
    root=tmp_path/'source';cache=tmp_path/'cache';cache.mkdir()
    package=root/'routepilot';package.mkdir(parents=True)
    (package/'__init__.py').write_text('')
    (package/'static').mkdir();(package/'static'/'app.js').write_text('first')
    (package/'__pycache__').mkdir();(package/'__pycache__'/'unused.pyc').write_bytes(b'old')
    first=prepare_source(root,cache)
    assert (first/'routepilot'/'static'/'app.js').read_text()=='first'
    assert not (first/'routepilot'/'__pycache__').exists()
    assert prepare_source(root,cache)==first
    (package/'static'/'app.js').write_text('second')
    second=prepare_source(root,cache)
    assert second!=first
    assert (first/'routepilot'/'static'/'app.js').read_text()=='first'
    assert (second/'routepilot'/'static'/'app.js').read_text()=='second'
    assert not list(cache.glob('app-staging-*'))


def test_port_reuse_requires_a_valid_controller_handshake(monkeypatch):
    import io
    import routepilot.__main__ as main
    class Opener:
        def __init__(self,responses):self.responses=iter(responses)
        def open(self,request,timeout):return io.BytesIO(next(self.responses))
    monkeypatch.setattr(main.urllib.request,'build_opener',lambda *args:Opener([b'<html>Another app</html>']))
    assert not main.existing_controller('http://127.0.0.1:8765')
    monkeypatch.setattr(main.urllib.request,'build_opener',lambda *args:Opener([b'<meta name="routepilot-token" content="sample">',b'{"active":false,"device":"preview"}']))
    assert main.existing_controller('http://127.0.0.1:8765')

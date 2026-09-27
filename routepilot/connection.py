"""Connection milestones shared by every browser tab, without simulated percentages."""
import time
import uuid


class ConnectionProgress:
    def __init__(self, changed=lambda: None, clock=time.monotonic):
        self.changed, self.clock = changed, clock
        self.attempt_id = None
        self.status = 'idle'
        self.steps = []
        self.started = self.finished = None
        self.error = None
        self.device = None

    def start(self):
        self.attempt_id = uuid.uuid4().hex
        self.status, self.steps, self.error = 'connecting', [], None
        self.device = None
        self.started, self.finished = self.clock(), None
        self.step('usb', 'Finding your iPhone', 'Checking the selected USB connection.')

    def select_device(self, serial, label=None):
        self.device = dict(id=serial, label=label or f'USB iPhone · …{serial[-8:]}')
        self.changed()

    def step(self, key, label, detail):
        now = self.clock()
        if self.steps:
            self.steps[-1].update(status='done', finished=now)
        self.steps.append(dict(key=key, label=label, detail=detail, status='working', started=now, finished=None))
        self.changed()

    def ready(self):
        self.finished = self.clock()
        if self.steps:
            self.steps[-1].update(status='done', finished=self.finished)
        self.status = 'ready'
        self.changed()

    def failed(self, error, cleaning=False):
        now = self.clock()
        if self.steps and self.steps[-1]['status'] == 'working':
            self.steps[-1].update(status='error', finished=now)
        self.error = error
        self.status = 'cleaning' if cleaning else 'error'
        self.finished = None if cleaning else now
        self.changed()

    def reset(self):
        self.__init__(self.changed, self.clock)
        self.changed()

    def snapshot(self):
        now = self.clock()
        elapsed = lambda start, end: round(max(0, (now if end is None else end) - start), 1)
        return dict(attempt_id=self.attempt_id, status=self.status, device=self.device,
                    active=self.status in ('connecting', 'cleaning'), error=self.error,
                    elapsed=elapsed(self.started, self.finished) if self.started is not None else 0,
                    steps=[dict(key=s['key'], label=s['label'], detail=s['detail'], status=s['status'],
                                elapsed=elapsed(s['started'], s['finished'])) for s in self.steps])

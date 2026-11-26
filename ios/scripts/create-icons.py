"""Render RoutePilot's simple code-defined icon at iOS PNG icon sizes."""
from pathlib import Path
import struct
import zlib

destination = Path(__file__).resolve().parents[1] / 'RoutePilot' / 'Resources'
polygon = [(302, 655), (565, 392), (390, 392), (390, 300), (725, 300), (725, 635), (633, 635), (633, 460), (367, 725)]

def inside(x, y):
    odd = False
    for (ax, ay), (bx, by) in zip(polygon, polygon[1:] + polygon[:1]):
        if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
            odd = not odd
    return odd

def chunk(tag, data):
    return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

for filename, size in [('AppIcon60x60@2x.png', 120), ('AppIcon60x60@3x.png', 180), ('AppIcon76x76@2x~ipad.png', 152), ('AppIcon83.5x83.5@2x~ipad.png', 167)]:
    rows = []
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            alpha = sum(inside((x + dx) * 1024 / size, (y + dy) * 1024 / size) for dx, dy in ((.25, .25), (.75, .25), (.25, .75), (.75, .75))) / 4
            row.extend(round(value * (1 - alpha) + 255 * alpha) for value in (35, 100, 73))
        rows.append(row)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b'')
    (destination / filename).write_bytes(data)

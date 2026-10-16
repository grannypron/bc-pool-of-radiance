"""Report the overlaid units' sizes, for build.sh.

usage: ovlsizes.py FIXMAIN.EXE FIXMAIN.MAP [--units]   (--units: every overlay's size too)

Each overlaid unit has a stub segment in the linked (unpacked) FIXMAIN.EXE: it starts with INT 3Fh (CD 3F), then the
return offset, the overlay's file offset (LongInt), its code size and its fixup size (Words). FIXMAIN.MAP gives each
code segment's start. A unit's load size is code plus fixups: what the overlay buffer must hold to run it.
"""
import re
import struct
import sys

OVERLAY_BUF = 100352


def main(exe_path, map_path, units=False):
    exe = open(exe_path, 'rb').read()
    image = exe[struct.unpack_from('<H', exe, 8)[0] * 16:]
    sizes = {}
    for line in open(map_path, encoding='latin1'):
        m = re.match(r'\s*([0-9A-F]{5})H\s+[0-9A-F]{5}H\s+([0-9A-F]{5})H\s+(\w+)\s+CODE', line)
        if not m or int(m.group(2), 16) == 0:
            continue
        start = int(m.group(1), 16)
        if image[start:start + 2] == b'\xcd\x3f':
            _ret, _ofs, code, fixups = struct.unpack_from('<HIHH', image, start + 2)
            sizes[m.group(3)] = code + fixups
    if not sizes:
        return
    largest = sorted(sizes.items(), key=lambda kv: -kv[1])[:3]
    print('overlays: %d units, %d bytes; largest %s; buffer %d bytes'
          % (len(sizes), sum(sizes.values()), ', '.join('%s %d' % kv for kv in largest), OVERLAY_BUF))
    if units:
        for name, size in sorted(sizes.items(), key=lambda kv: -kv[1]):
            print('  %-10s %6d' % (name, size))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], '--units' in sys.argv[3:])

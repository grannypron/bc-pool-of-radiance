#!/usr/bin/env python3
"""Build SBSFX.DAT, the Sound Blaster driver's recorded effects (docs/refactor-plan.md, phase 7, step 4).

    tools/sbsfx.py [--pools ZOUNDS.DAX] [--dqk SFXDQ.VOC] [--out drive_c/POOLRAD/SBSFX.DAT]

No Gold Box game plays its effects through FM. Pools of Darkness plays them as recorded samples from ZOUNDS.DAX
(through DIGPAK; on a Sound Blaster, SND.COM), and Dark Queen of Krynn from SFXDQ.VOC. This takes PoR's effect sounds
from them, as SSI shipped them:

- Pools' ZOUNDS.DAX blocks are Amiga IFF 8SVX files with every byte XOR 80h. A sample is found by the name in its
  NAME chunk, and its BODY (signed 8-bit) becomes unsigned 8-bit. Pools plays every effect at 9000 Hz whatever its
  VHDR says, so that is the rate kept.
- Dark Queen's hero-falls sound is one block of SFXDQ.VOC, 4-bit Creative ADPCM; ffmpeg decodes it, from that block
  alone written as a VOC file of its own, and its 16-bit result becomes unsigned 8-bit at the block's rate.

SBSFX.DAT: 'SBFX', a version byte (1), the entry count; then per entry the tune (SoundDrv's tune id, the sound
command less one), the rate in Hz, the length and the offset of its bytes from the start of the file (Words, little
endian); then the samples, each stored once however many tunes play it. Needs goldbox-re-tools (GBRE_SRC, by default
~/repos/goldbox-re-tools/src) for the DAX reader, and ffmpeg.
"""
import argparse
import os
import pathlib
import struct
import subprocess
import sys
import tempfile

HOME = pathlib.Path.home()
ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, os.environ.get("GBRE_SRC", str(HOME / "repos/goldbox-re-tools/src")))
from goldbox import dax_tool as D  # noqa: E402

POOLS_RATE = 9000
# tune -> source: ('pools', NAME) or ('dqk', VOC block index, 0 first)
TUNES = {
    1: ("pools", "Zorp"),               # a spell is cast
    2: ("pools", "fireb"),              # non-weapon damage
    3: ("pools", "Tuning.Fork.2"),      # a spell's effect lands on a creature
    4: ("dqk", 3),                      # a creature goes down: Dark Queen's hero falls
    5: ("pools", "arrow"),              # a missile is launched
    6: ("pools", "fireb"),              # a weapon hits; the party bumps a wall
    7: ("pools", "lightning"),          # Lightning Bolt
    8: ("pools", "ropeswish2"),         # a miss
    9: ("pools", "pad2"),               # a step
    10: ("pools", "fireb"),             # Fireball, and the scripts' cue
    11: ("pools", "hit5"),              # a missile lands; Pools ships it and never plays it
}


def pools_samples(path: pathlib.Path) -> dict:
    """NAME -> unsigned 8-bit samples, from ZOUNDS.DAX's 8SVX blocks."""
    data = path.read_bytes()
    off, entries = D.parse_header(data)
    found = {}
    for e in entries:
        b = bytes(x ^ 0x80 for x in D.extract_block(data, off, e))
        if b[:4] != b"FORM" or b[8:12] != b"8SVX":
            continue
        pos, name, body = 12, None, None
        while pos + 8 <= len(b):
            cid = b[pos:pos + 4]
            ln = struct.unpack(">I", b[pos + 4:pos + 8])[0]
            chunk = b[pos + 8:pos + 8 + ln]
            if cid == b"NAME":
                name = chunk.rstrip(b"\0").decode("latin-1")
            elif cid == b"BODY":
                body = chunk
            pos += 8 + ln + (ln & 1)
        if name and body:
            found.setdefault(name, bytes(x ^ 0x80 for x in body))
    return found


def voc_blocks(data: bytes) -> list:
    """SFXDQ.VOC's sound blocks (type 1): (time constant, pack, data) each."""
    if not data.startswith(b"Creative Voice File\x1a"):
        raise SystemExit("sbsfx.py: not a Creative Voice File")
    pos = struct.unpack("<H", data[20:22])[0]
    blocks = []
    while pos < len(data) and data[pos] != 0:
        kind = data[pos]
        ln = data[pos + 1] | data[pos + 2] << 8 | data[pos + 3] << 16
        body = data[pos + 4:pos + 4 + ln]
        if kind == 1:
            blocks.append((body[0], body[1], body[2:]))
        pos += 4 + ln
    return blocks


def dqk_sample(path: pathlib.Path, index: int) -> tuple:
    """(rate, unsigned 8-bit samples) for VOC block index, decoded by ffmpeg."""
    tc, pack, body = voc_blocks(path.read_bytes())[index]
    rate = round(1000000 / (256 - tc))
    one = bytearray(b"Creative Voice File\x1a" + struct.pack("<HHH", 26, 0x010A, 0x1129 + 0x010A))
    payload = bytes([tc, pack]) + body
    one += bytes([1]) + struct.pack("<I", len(payload))[:3] + payload + b"\0"
    with tempfile.TemporaryDirectory() as tmp:
        voc = pathlib.Path(tmp) / "one.voc"
        voc.write_bytes(one)
        pcm = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(voc), "-f", "u8", "-ac", "1", "-"],
                             check=True, capture_output=True).stdout
    return rate, pcm


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--pools", type=pathlib.Path, default=HOME / "repos/pools-disassembly/drive_c/POOLS.V11/ZOUNDS.DAX")
    ap.add_argument("--dqk", type=pathlib.Path, default=HOME / "repos/dqk-disassembly/drive_c/DQK.V11/DISK1/SFXDQ.VOC")
    ap.add_argument("--out", type=pathlib.Path, default=ROOT / "drive_c/POOLRAD/SBSFX.DAT")
    args = ap.parse_args()
    pools = pools_samples(args.pools)
    sources = {}
    for tune, src in TUNES.items():
        if src not in sources:
            if src[0] == "pools":
                if src[1] not in pools:
                    raise SystemExit("sbsfx.py: ZOUNDS.DAX has no sample named %r" % src[1])
                sources[src] = (POOLS_RATE, pools[src[1]])
            else:
                sources[src] = dqk_sample(args.dqk, src[1])
    order = list(dict.fromkeys(TUNES.values()))
    header = 6 + 7 * len(TUNES)
    offsets, pos = {}, header
    for src in order:
        offsets[src] = pos
        pos += len(sources[src][1])
    if pos > 0xFFFF:
        raise SystemExit("sbsfx.py: the samples come to %d bytes, past a Word's reach" % pos)
    out = bytearray(b"SBFX" + bytes([1, len(TUNES)]))
    for tune, src in sorted(TUNES.items()):
        rate, pcm = sources[src]
        out += struct.pack("<BHHH", tune, rate, len(pcm), offsets[src])
    for src in order:
        out += sources[src][1]
    args.out.write_bytes(out)
    for tune, src in sorted(TUNES.items()):
        rate, pcm = sources[src]
        print("tune %2d  %-22s %5d Hz %5d bytes  %4.0f ms" % (tune, "%s %s" % src, rate, len(pcm),
                                                              1000 * len(pcm) / rate))
    print("sbsfx.py: wrote %s, %d bytes" % (args.out, len(out)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

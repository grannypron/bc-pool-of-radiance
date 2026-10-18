#!/usr/bin/env python3
"""Build SBSFX.DAT, the Sound Blaster driver's recorded effects (docs/refactor-plan.md, phase 7, step 4).

    tools/sbsfx.py [--pools ZOUNDS.DAX] [--dqk SFXDQ.VOC] [--out drive_c/POOLRAD/SBSFX.DAT]

No Gold Box game plays its effects through FM. Dark Queen of Krynn plays them on a Sound Blaster from SFXDQ.VOC (the
same file FRUA ships), and Pools of Darkness from ZOUNDS.DAX. PoR's effects take Dark Queen's, as SSI shipped them,
all but the footstep: Dark Queen's is not the owner's favourite and Pools' is three thumps, the first itself a heel and
a toe, so the step is that first thump's stronger hit alone.

- Dark Queen's sounds are blocks of SFXDQ.VOC, in FRUA's order (Cast, Blast, Sorcery, Death, Missile, Hit, Lightning,
  Swish, Footstep, Fireball, Bowstring, Sploosh, Crackle), each 4-bit Creative ADPCM with its reference byte first.
  They are kept as they are: the Sound Blaster's DSP plays that format itself (command 75h), at half the size of the
  samples decoded.
- Pools' ZOUNDS.DAX blocks are Amiga IFF 8SVX files with every byte XOR 80h. A sample is found by the name in its NAME
  chunk, and its BODY (signed 8-bit) becomes unsigned 8-bit, played at 9000 Hz as Pools plays every effect.

SBSFX.DAT: 'SBFX', a version byte (2), the entry count; then per entry the tune (SoundDrv's tune id, the sound command
less one), the format (0 unsigned 8-bit PCM, 1 4-bit ADPCM with its reference byte), the DSP time constant (256 -
1000000 / rate), and the length and the offset of its bytes from the start of the file (Words, little endian); then
the samples, each stored once however many tunes play it. Needs goldbox-re-tools (GBRE_SRC, by default
~/repos/goldbox-re-tools/src) for the DAX reader.
"""
import argparse
import os
import pathlib
import struct
import sys

HOME = pathlib.Path.home()
ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, os.environ.get("GBRE_SRC", str(HOME / "repos/goldbox-re-tools/src")))
from goldbox import dax_tool as D  # noqa: E402

POOLS_RATE = 9000
PCM8 = 0
ADPCM4 = 1
# Dark Queen's blocks in SFXDQ.VOC, by FRUA's names
DQK = {"Cast": 0, "Blast": 1, "Sorcery": 2, "Death": 3, "Missile": 4, "Hit": 5, "Lightning": 6, "Swish": 7,
       "Footstep": 8, "Fireball": 9, "Bowstring": 10, "Sploosh": 11, "Crackle": 12}
# Pools' "pad2" is three thumps, the first itself two hits (heel and toe: 0-8 ms, then 14-25 ms); the step is the
# stronger second hit alone, faded in and out so it neither clicks nor doubles
STEP_FROM_MS = 13
STEP_TO_MS = 33
STEP_FADE_MS = 2
# Pools recorded its step near full scale (peaks about 120 of 128), Dark Queen its effects far lower: measured in the
# owner's recording, the step peaked about four times higher than Dark Queen's hits and misses, so it is scaled to a
# quarter
STEP_GAIN = 0.25
# tune -> source: ('dqk', name) or ('pools-first-step', NAME)
TUNES = {
    1: ("dqk", "Cast"),                     # a spell is cast
    2: ("dqk", "Blast"),                    # non-weapon damage
    3: ("dqk", "Sorcery"),                  # a spell's effect lands on a creature
    4: ("dqk", "Death"),                    # a creature goes down
    5: ("dqk", "Missile"),                  # a missile is launched, as Dark Queen plays for a bow or crossbow
    6: ("dqk", "Hit"),                      # a weapon hits; the party bumps a wall
    7: ("dqk", "Lightning"),                # Lightning Bolt
    8: ("dqk", "Swish"),                    # a miss
    9: ("pools-first-step", "pad2"),        # a step: one hit of the first of Pools' three thumps
    10: ("dqk", "Fireball"),                # Fireball, and the scripts' cue
    11: ("dqk", "Hit"),                     # a missile lands
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


def dqk_sample(blocks: list, name: str) -> tuple:
    """(format, time constant, bytes) for Dark Queen's sound name: its 4-bit ADPCM block as it is."""
    tc, pack, body = blocks[DQK[name]]
    if pack != 1:
        raise SystemExit("sbsfx.py: SFXDQ.VOC's %s is packed %d, not 4-bit ADPCM" % (name, pack))
    return ADPCM4, tc, body


def first_step(pools: dict, name: str) -> tuple:
    """(format, time constant, bytes): STEP_FROM_MS to STEP_TO_MS of Pools' sample name at 9000 Hz, one hit, at
    STEP_GAIN of its recorded level and faded in and out over STEP_FADE_MS so it ends without a click."""
    pcm = bytearray(round(128 + (x - 128) * STEP_GAIN)
                    for x in pools[name][POOLS_RATE * STEP_FROM_MS // 1000:POOLS_RATE * STEP_TO_MS // 1000])
    fade = POOLS_RATE * STEP_FADE_MS // 1000
    for k in range(fade):
        pcm[k] = round(128 + (pcm[k] - 128) * k / fade)
        i = len(pcm) - fade + k
        pcm[i] = round(128 + (pcm[i] - 128) * (fade - k) / fade)
    return PCM8, 256 - 1000000 // POOLS_RATE, bytes(pcm)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--pools", type=pathlib.Path, default=HOME / "repos/pools-disassembly/drive_c/POOLS.V11/ZOUNDS.DAX")
    ap.add_argument("--dqk", type=pathlib.Path, default=HOME / "repos/dqk-disassembly/drive_c/DQK.V11/DISK1/SFXDQ.VOC")
    ap.add_argument("--out", type=pathlib.Path, default=ROOT / "drive_c/POOLRAD/SBSFX.DAT")
    args = ap.parse_args()
    pools = pools_samples(args.pools)
    blocks = voc_blocks(args.dqk.read_bytes())
    sources = {}
    for tune, src in TUNES.items():
        if src not in sources:
            if src[0] == "dqk":
                sources[src] = dqk_sample(blocks, src[1])
            else:
                if src[1] not in pools:
                    raise SystemExit("sbsfx.py: ZOUNDS.DAX has no sample named %r" % src[1])
                sources[src] = first_step(pools, src[1])
    order = list(dict.fromkeys(TUNES.values()))
    header = 6 + 7 * len(TUNES)
    offsets, pos = {}, header
    for src in order:
        offsets[src] = pos
        pos += len(sources[src][2])
    if pos > 0xFFFF:
        raise SystemExit("sbsfx.py: the samples come to %d bytes, past a Word's reach" % pos)
    out = bytearray(b"SBFX" + bytes([2, len(TUNES)]))
    for tune, src in sorted(TUNES.items()):
        fmt, tc, data = sources[src]
        out += struct.pack("<BBBHH", tune, fmt, tc, len(data), offsets[src])
    for src in order:
        out += sources[src][2]
    args.out.write_bytes(out)
    for tune, src in sorted(TUNES.items()):
        fmt, tc, data = sources[src]
        rate = 1000000 // (256 - tc)
        samples = 2 * (len(data) - 1) + 1 if fmt == ADPCM4 else len(data)
        print("tune %2d  %-26s %-6s %5d Hz %5d bytes %5.0f ms" % (tune, "%s %s" % src, ("PCM8", "ADPCM4")[fmt], rate,
                                                                 len(data), 1000 * samples / rate))
    print("sbsfx.py: wrote %s, %d bytes" % (args.out, len(out)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

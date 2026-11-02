#!/usr/bin/env python3
"""Build the demo's archive, DEMO.DAX (#1109), from the files in src/demo.

    scripts/demodax.py [--out src/binaries/DEMO.DAX]
    scripts/demodax.py --check        # the committed src/binaries/DEMO.DAX is what these sources build

The Commodore 64 release played a demo when the title was left alone. It is one ECL script, ECL1E on the C64's first
disk, in the bytecode PoR's PC scripts use: the same opcodes, the same five-entry header and nearly every address one
the PC's VM maps. src/demo holds that file as the C64 disk has it (ecl1e.bin: two header bytes, then the script from
$9900), and the four characters it adds to the party, converted from the C64's 480-byte monster records into the PC's
285-byte MON*CHA records and 63-byte MON*ITM items (restal, tarran, diane, william .cha and .itm). The conversion and
its check against 147 C64/PC record pairs are in the c64-demo-extract archive on #1109 (tools/c64mon.py). RESTAL and
TARRAN are the PC's "4TH LVL FIGHTER" (MON1CHA 41) renamed, DIANE is MON7CHA 79, WILLIAM D'OR is DIRTEN (MON3CHA 107)
renamed.

The archive holds the script as block SCRIPT_BLOCK and each character's record as block FIRST_NPC + n, its items as
block FIRST_NPC + n + ITEMS_OFFSET (C_DEMO in src/includes/c_demo.pas has the same numbers). The script is changed only
where PATCHES says, each change checked against the C64 bytes it replaces, and the routines it calls are added past its
end (ADDED), so no address in the C64 script moves:
- ADD NPC takes the demo's own ids: on the PC, 22, 23 and 107 are other monsters, and 79 is DIANE only on disk 7.
- Each caption's pause calls CAPTION_PAUSE, which waits longer before the C64's own pause routine at $9D73 (two DELAYs,
  then its key check): one DELAY at the demo's speed is 450 ms, too short to read a caption of four or five lines.
- After the battle, the view's refresh calls AFTER_COMBAT, which ends the demo when the party did not win (COMBAT_RESULT
  not 0), then refreshes the view as before.
- The pause once Podol Plaza is loaded calls CLEAR_PICTURE, which takes the title portrait down (PICTURE 255) before
  the C64's pause: on the PC a picture shown stays the view's (EclMenu.monsterFlags) until then, and the ogre SETUP
  MONSTER puts in the view later would not be drawn.

A block is packed with the DAX run-length code DaxIo.DecompressDax reads.
"""
import argparse
import pathlib
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src/demo"
OUT = ROOT / "src/binaries/DEMO.DAX"

SCRIPT_BLOCK = 1
FIRST_NPC = 240
ITEMS_OFFSET = 8
NPCS = ("restal", "tarran", "diane", "william")
# the ids the C64 script adds, in NPCS's order
C64_NPCS = (22, 23, 79, 107)

SCRIPT_FIRST = 0x9900
HEADER = 2
# the C64 script ends at $9E3B; the added routines follow
CAPTION_PAUSE = 0x9E3C
# DELAYs before the C64's pause routine: with its own two, 14 x 450 ms, about six seconds a caption
CAPTION_DELAYS = 12
C64_PAUSE = 0x9D73
DEMO_END = 0x9D41
COMBAT_RESULT = 0x6DC7
REFRESH_VIEW = 0x2C90

DELAY = 0x3A
GOTO = 0x01
GOSUB = 0x02
COMPARE = 0x03
IF_NE = 0x17
CALL = 0x2D
RETURN = 0x13
PICTURE = 0x0E


def addr(op: int, a: int) -> bytes:
    """An opcode with one address operand (type 1, low byte first)."""
    return bytes([op, 1, a & 0xFF, a >> 8])


# CAPTION_PAUSE: DELAY x CAPTION_DELAYS; GOTO the C64's pause
CAPTION_CODE = bytes([DELAY]) * CAPTION_DELAYS + addr(GOTO, C64_PAUSE)
# AFTER_COMBAT: COMPARE [COMBAT_RESULT], #0; IF <>; GOTO the end; CALL refresh; RETURN
AFTER_COMBAT = CAPTION_PAUSE + len(CAPTION_CODE)
AFTER_CODE = (bytes([COMPARE, 1, COMBAT_RESULT & 0xFF, COMBAT_RESULT >> 8, 0, 0, IF_NE]) + addr(GOTO, DEMO_END)
              + addr(CALL, REFRESH_VIEW) + bytes([RETURN]))
# CLEAR_PICTURE: PICTURE #255; GOTO the C64's pause
CLEAR_PICTURE = AFTER_COMBAT + len(AFTER_CODE)
CLEAR_CODE = bytes([PICTURE, 0, 255]) + addr(GOTO, C64_PAUSE)
ADDED = CAPTION_CODE + AFTER_CODE + CLEAR_CODE

# (address, the C64's bytes there, ours): the four ADD NPCs at $995C, five bytes apart, take the demo's ids
PATCHES = [(0x995C + 5 * i + 2, bytes([c]), bytes([FIRST_NPC + i])) for i, c in enumerate(C64_NPCS)]
# the six captions' pauses
PATCHES += [(a, addr(GOSUB, C64_PAUSE), addr(GOSUB, CAPTION_PAUSE))
            for a in (0x9A3E, 0x9AD9, 0x9B89, 0x9BFA, 0x9C89, 0x9D3D)]
PATCHES += [(0x9CAF, addr(CALL, REFRESH_VIEW), addr(GOSUB, AFTER_COMBAT))]
# the pause once Podol Plaza is loaded
PATCHES += [(0x9A62, addr(GOSUB, C64_PAUSE), addr(GOSUB, CLEAR_PICTURE))]


def script() -> bytes:
    """The C64 script, with its patches made and the added routines appended."""
    data = bytearray((SRC / "ecl1e.bin").read_bytes())
    if len(data) != HEADER + CAPTION_PAUSE - SCRIPT_FIRST:
        sys.exit("demodax.py: ecl1e.bin is %d bytes, not the C64 file's %d" % (len(data), HEADER + CAPTION_PAUSE -
                                                                                SCRIPT_FIRST))
    for at, old, new in PATCHES:
        o = HEADER + at - SCRIPT_FIRST
        if data[o:o + len(old)] != old:
            sys.exit("demodax.py: ecl1e.bin at $%04X holds %s, not %s" % (at, data[o:o + len(old)].hex(), old.hex()))
        data[o:o + len(new)] = new
    return bytes(data) + ADDED


def pack(raw: bytes) -> bytes:
    """DAX run-length code: 0..$7E copies the next b + 1 bytes, $81..$FF repeats the next byte 256 - b times."""
    out = bytearray()
    lit = bytearray()
    i = 0

    def flush():
        while lit:
            chunk = lit[:127]
            out.append(len(chunk) - 1)
            out.extend(chunk)
            del lit[:127]

    while i < len(raw):
        n = 1
        while i + n < len(raw) and raw[i + n] == raw[i] and n < 127:
            n += 1
        if n >= 3:
            flush()
            out.append(256 - n)
            out.append(raw[i])
            i += n
        else:
            lit.append(raw[i])
            i += 1
    flush()
    return bytes(out)


def build() -> bytes:
    blocks = [(SCRIPT_BLOCK, script())]
    for i, name in enumerate(NPCS):
        cha = (SRC / (name + ".cha")).read_bytes()
        itm = (SRC / (name + ".itm")).read_bytes()
        if len(cha) != 285 or len(itm) % 63:
            sys.exit("demodax.py: %s.cha must be 285 bytes and %s.itm whole 63-byte items" % (name, name))
        blocks.append((FIRST_NPC + i, cha))
        blocks.append((FIRST_NPC + i + ITEMS_OFFSET, itm))
    directory = bytearray()
    body = bytearray()
    for bid, raw in blocks:
        packed = pack(raw)
        directory += struct.pack("<BiHH", bid, len(body), len(raw), len(packed))
        body += packed
    return struct.pack("<H", len(directory)) + bytes(directory) + bytes(body)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=pathlib.Path, default=OUT)
    ap.add_argument("--check", action="store_true", help="compare with --out instead of writing it")
    a = ap.parse_args()
    data = build()
    if a.check:
        if not a.out.is_file() or a.out.read_bytes() != data:
            print("demodax.py: %s is not what src/demo builds; run scripts/demodax.py" % a.out)
            return 1
        print("demodax.py: %s is current" % a.out)
        return 0
    a.out.write_bytes(data)
    print("demodax.py: wrote %s (%d bytes)" % (a.out, len(data)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

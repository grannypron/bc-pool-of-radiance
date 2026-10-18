#!/usr/bin/env python3
"""Turn the sequencer's data into Pascal for the native build's sequencer (SndSeq).

    tools/snd2pas.py [--src src] [--out obj/SNDIMAGE.INC]

sounddrv.asm's tunes are streams of bytes that point at each other, at envelopes and at the LFO waveforms by their
offsets in the driver's segment, and the voice blocks they write are in that segment too. The native sequencer runs
the same streams over a 64 KB image of that segment, so this assembles the data the way TASM does:

- sounddrv.asm from lfoSine (the LFO waveforms) up to its INCLUDE of sndopl.inc, which the native build does not
  play; the VOICE structure and the stream macros are read from the same file;
- sndspk.inc and sndtdy.inc, each up to its tick routine (the code after it is the native sequencer's to port).

Code between the data is left out, so the offsets are not the DOS build's, but every pointer is assembled against
this image, and data that sits together in the DOS segment sits together here (an LFO read past one waveform reaches
the next, as on DOS). The output is a Pascal include: the image as a typed constant, the offset it loads at, the
VOICE fields' offsets and the labels the sequencer needs.
"""
import argparse
import pathlib
import re
import sys

# where the image starts in the native sequencer's 64 KB segment: room below for a read before the first table
ORG = 0x0100

# labels the native sequencer names, and the constant each becomes
EXPORTS = {
    "spkrBlocks": "SPKR_BLOCKS",
    "spkrFreq": "SPKR_FREQ",
    "songTableA": "SONG_TABLE_A",
    "SONG_ROWS_A": "SONG_ROWS_A",
    "tandyBlocks": "TANDY_BLOCKS",
    "tandyFreq": "TANDY_FREQ",
    "songTableB": "SONG_TABLE_B",
    "SONG_ROWS_B": "SONG_ROWS_B",
    "REST": "REST",
    "OCT": "OCT",
    "ENV_SETLEVEL": "ENV_SETLEVEL",
}


def fail(where, msg):
    sys.exit(f"snd2pas: {where}: {msg}")


def strip_comment(line):
    return line.split(";", 1)[0].rstrip()


def read_struct(lines):
    """VOICE's field offsets and size, from its STRUC block."""
    fields = {}
    size = 0
    inside = False
    for line in lines:
        text = strip_comment(line)
        words = text.split()
        if not words:
            continue
        if len(words) >= 2 and words[0] == "VOICE" and words[1] == "STRUC":
            inside = True
            continue
        if not inside:
            continue
        if words[0] == "VOICE" and words[1] == "ENDS":
            return fields, size
        m = re.match(r"^(\w+)?\s*dw\s+(.*)$", text.strip())
        if not m:
            fail("VOICE", f"cannot read {text!r}")
        dup = re.match(r"(\d+)\s+dup\(0\)", m.group(2).strip())
        if m.group(1):
            fields[m.group(1)] = size
        size += 2 * (int(dup.group(1)) if dup else 1)
    fail("VOICE", "no ENDS")


class Assembler:
    def __init__(self, voice_fields, voice_size):
        self.fields = voice_fields
        self.voice_size = voice_size
        self.symbols = {}
        self.equs = []

    def number(self, m):
        tok = m.group(0)
        if tok[-1] in "hH":
            return str(int(tok[:-1], 16))
        return str(int(tok, 10))

    def value(self, expr, here, where, final):
        """The value of a TASM expression: numbers, symbols, SIZE VOICE, $, + - * / SHL OR and parentheses."""
        text = expr.strip()
        text = re.sub(r"\bSIZE\s+VOICE\b", str(self.voice_size), text)
        text = text.replace("$", str(here))
        text = re.sub(r"\b\d[0-9A-Fa-f]*[hH]\b|\b\d+\b", self.number, text)
        text = re.sub(r"\bSHL\b", "<<", text)
        text = re.sub(r"\bOR\b", "|", text)
        text = text.replace("/", "//")

        def name(m):
            n = m.group(0)
            if n in self.fields:
                return str(self.fields[n])
            if n in self.symbols:
                return str(self.symbols[n])
            if final:
                fail(where, f"unknown symbol {n}")
            return "0"
        text = re.sub(r"\b[A-Za-z_]\w*\b", name, text)
        try:
            return eval(text, {"__builtins__": {}})
        except Exception as e:
            fail(where, f"cannot evaluate {expr!r}: {e}")

    def items(self, args):
        return [a.strip() for a in args.split(",")] if args.strip() else []

    def run(self, lines, final):
        """One pass over (where, text) lines: the bytes, with symbols from the last pass when final."""
        out = bytearray()
        here = ORG

        def byte(v, where):
            out.append(v & 0xFF)

        def word(v, where):
            out.append(v & 0xFF)
            out.append((v >> 8) & 0xFF)

        for where, text in lines:
            text = text.strip()
            m = re.match(r"^(\w+):\s*(.*)$", text)
            if m:
                self.symbols[m.group(1)] = ORG + len(out)
                text = m.group(2)
            if not text:
                continue
            words = text.split(None, 1)
            if len(words) == 2:
                m = re.match(r"^(\w+)\s+(equ|db|dw|VOICE)\b\s*(.*)$", text)
                if m:
                    label, op, rest = m.groups()
                    if op == "equ":
                        self.symbols[label] = self.value(rest, ORG + len(out), where, final)
                        continue
                    self.symbols[label] = ORG + len(out)
                    words = [op, rest]
            op = words[0]
            args = words[1] if len(words) > 1 else ""
            here = ORG + len(out)
            v = lambda e: self.value(e, here, where, final)
            a = self.items(args)
            if op == "db":
                for e in a:
                    byte(v(e), where)
            elif op == "dw":
                for e in a:
                    word(v(e), where)
            elif op == "VOICE":
                out.extend(bytes(self.voice_size))
            elif op == "SRESET":
                byte(0xFA, where)
            elif op == "SRET":
                byte(0xFB, where)
            elif op == "SCALL":
                byte(0xFC, where)
                word(v(a[0]), where)
            elif op == "SCLEAR":
                byte(0xFD, where)
                word(v(a[0]) * self.voice_size, where)
            elif op == "SLOOP":
                byte(0xFE, where)
                byte(v(a[0]), where)
                word(v(a[1]), where)
            elif op == "SSET":
                byte(0xFF, where)
                byte(v(a[0]), where)
                word(v(a[1]), where)
            elif op == "SWAIT":
                byte(0xFF, where)
                byte(0, where)
                word(v(a[0]), where)
            elif op == "SENV":
                word(v(a[0]), where)
                word(v(a[1]), where)
            elif op == "SNOTE":
                vnum, length, pitch, last, dur = (v(e) for e in a)
                byte((vnum << 5) | length, where)
                byte((last << 7) | pitch, where)
                byte(dur, where)
            else:
                fail(where, f"not data: {text!r}")
        return out


def data_lines(src):
    """(where, text) for every data line, in the order TASM assembles them."""
    core = (src / "sounddrv.asm").read_text().splitlines()
    lines = []
    started = False
    in_macro = False
    for n, line in enumerate(core, 1):
        text = strip_comment(line)
        if not started:
            started = text.startswith("lfoSine")
            if not started:
                continue
        words = text.split()
        if len(words) >= 2 and words[1] == "MACRO":
            in_macro = True
            continue
        if in_macro:
            in_macro = words[:1] != ["ENDM"]
            continue
        if words[:1] == ["INCLUDE"]:
            name = words[1]
            if name == "sndopl.inc":
                break
            for k, inc in enumerate((src / name).read_text().splitlines(), 1):
                itext = strip_comment(inc)
                if re.match(r"^tick_\w+:", itext):
                    break
                if itext.strip():
                    lines.append((f"{name}:{k}", itext))
            continue
        if text.strip():
            lines.append((f"sounddrv.asm:{n}", text))
    if not started:
        fail("sounddrv.asm", "no lfoSine")
    return core, lines


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--src", default="src")
    ap.add_argument("--out", default="obj/SNDIMAGE.INC")
    args = ap.parse_args()
    src = pathlib.Path(args.src)
    core, lines = data_lines(src)
    fields, size = read_struct(core)
    asm = Assembler(fields, size)
    asm.run(lines, final=False)
    image = asm.run(lines, final=True)
    if ORG + len(image) > 0x10000:
        fail("image", f"{len(image)} bytes do not fit")

    out = []
    out.append("{ Generated by tools/snd2pas.py from sounddrv.asm, sndspk.inc and sndtdy.inc: do not edit. The sequencer's")
    out.append("  data as a segment image for SndSeq, the VOICE fields' offsets and the labels it uses. }")
    out.append("const")
    out.append(f"  SND_ORG = ${ORG:04X};")
    out.append(f"  SND_IMAGE_BYTES = {len(image)};")
    out.append(f"  VOICE_SIZE = {size};")
    for name, ofs in fields.items():
        pas = "VF_" + re.sub(r"(?<!^)(?=[A-Z])", "_", name[2:]).upper()
        out.append(f"  {pas} = {ofs};")
    for name, pas in EXPORTS.items():
        if name not in asm.symbols:
            fail("labels", f"no {name}")
        out.append(f"  {pas} = ${asm.symbols[name] & 0xFFFF:04X};")
    out.append(f"  SND_IMAGE: array[0..{len(image) - 1}] of Byte = (")
    for i in range(0, len(image), 24):
        chunk = ", ".join(f"${b:02X}" for b in image[i:i + 24])
        out.append(f"    {chunk}{',' if i + 24 < len(image) else ');'}")
    path = pathlib.Path(args.out)
    path.parent.mkdir(parents=True, exist_ok=True)
    text = "\n".join(out) + "\n"
    if not path.exists() or path.read_text() != text:
        path.write_text(text)


if __name__ == "__main__":
    main()

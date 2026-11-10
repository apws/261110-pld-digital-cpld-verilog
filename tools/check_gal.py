#!/usr/bin/env python3
"""Build examples, then evaluate their actual JEDEC product terms exhaustively.

This checks these two fixed example architectures, not arbitrary JEDEC files.
It is independent of the PLD equation parser and is not electrical simulation.
"""
from pathlib import Path
import hashlib
import itertools
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "gal"


def read_jed(path, count):
    text = path.read_text()
    assert int(re.search(r"\*QF(\d+)", text)[1]) == count
    default = int(re.search(r"\*F([01])", text)[1])
    fuses = [default] * count
    for match in re.finditer(r"\*L(\d+)\s+([01\s]+)(?=\*)", text):
        start = int(match[1])
        bits = [int(b) for b in match[2] if b in "01"]
        assert start + len(bits) <= count
        fuses[start:start + len(bits)] = bits
    checksum = sum(sum(bit << n for n, bit in enumerate(fuses[i:i+8]))
                   for i in range(0, count, 8)) & 0xffff
    assert checksum == int(re.search(r"\*C([0-9a-fA-F]{4})", text)[1], 16)
    raw = path.read_bytes()
    end = raw.index(b"\x03")
    assert sum(raw[raw.index(b"\x02"):end+1]) & 0xffff == int(raw[end+1:end+5], 16)
    return fuses


def product(fuses, row, width, values):
    for col in range(0, width, 2):
        value = values.get(col, 0)
        if not fuses[row * width + col] and not value:
            return False
        if not fuses[row * width + col + 1] and value:
            return False
    return True


def sop(fuses, start, count, width, values):
    return any(product(fuses, row, width, values)
               for row in range(start, start + count))


def main():
    subprocess.run(["make", "-C", str(ROOT / "vendor/GALasm/src")], check=True)
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ("decode16v8", "bank22v10"):
        target = OUT / (name + ".pld")
        shutil.copyfile(ROOT / "examples/gal" / target.name, target)
        subprocess.run([str(ROOT / "vendor/GALasm/src/galasm"), "-v", str(target)], check=True)

    f = read_jed(OUT / "decode16v8.jed", 2194)
    assert (f[2192], f[2193]) == (1, 0), "expected simple mode"
    assert f[2048:2052] == [1] * 4, "expected active-high equation polarity"
    assert f[2120:2124] == [0] * 4, "expected combinational cells"
    for a15, a14, a13, mreq, rd, wr in itertools.product((0, 1), repeat=6):
        values = dict(zip((0, 4, 8, 12, 16, 20), (a15, a14, a13, mreq, rd, wr)))
        expected = (bool(mreq or a15 or a14 or a13), bool(mreq or not a15),
                    bool(mreq or rd), bool(mreq or wr))
        actual = tuple(sop(f, i * 8, 8, 32, values) for i in range(4))
        assert actual == expected, (values, actual, expected)
    print("PASS: GAL16V8 JEDEC decoder, all 64 input combinations", flush=True)

    f = read_jed(OUT / "bank22v10.jed", 5892)
    assert f[5808:5814] == [1, 0, 1, 0, 1, 1], "Q0/Q1 registered; FLAG combinational"
    # OE rows: Q0=1, Q1=10, FLAG=21; unused output-capable EXT pin14=122.
    assert all(f[row * 44:(row + 1) * 44] == [1] * 44 for row in (1, 10, 21))
    assert f[122 * 44:123 * 44] == [0] * 44, "EXT output must be disabled"
    assert f[0:44] == [0] * 44 and f[131 * 44:132 * 44] == [0] * 44
    for reset, load, d0, d1, ext, q0, q1 in itertools.product((0, 1), repeat=7):
        # Active-high registered feedback on a 22V10 reaches the array inverted.
        values = {4: reset, 8: load, 12: d0, 16: d1, 38: ext, 2: 1-q0, 6: 1-q1}
        expected = (bool(not reset and (d0 if load else q0)),
                    bool(not reset and (d1 if load else q1)),
                    bool(ext and q0 and not q1))
        actual = (sop(f, 2, 8, 44, values), sop(f, 11, 10, 44, values),
                  sop(f, 22, 12, 44, values))
        assert actual == expected, (values, actual, expected)
    print("PASS: GAL22V10 JEDEC next-state/flag, all 128 input/state combinations", flush=True)
    for path in sorted(OUT.glob("*.jed")):
        print(hashlib.sha256(path.read_bytes()).hexdigest(), path.relative_to(ROOT), flush=True)


if __name__ == "__main__":
    main()

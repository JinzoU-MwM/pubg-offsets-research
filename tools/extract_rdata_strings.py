#!/usr/bin/env python3
"""Ekstrak korpus string UTF-16 dari section .rdata (plaintext) TslGame.exe.

Pemakaian: python3 extract_rdata_strings.py TslGame.exe out.txt
"""
import re
import struct
import sys


def sections(data):
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    nsec = struct.unpack_from("<H", data, pe + 6)[0]
    opt_size = struct.unpack_from("<H", data, pe + 20)[0]
    so = pe + 24 + opt_size
    out = []
    for i in range(nsec):
        off = so + i * 40
        name = data[off:off + 8].rstrip(b"\x00").decode("latin1", "replace")
        vsize, va, rsize, roff = struct.unpack_from("<IIII", data, off + 8)
        out.append((name, vsize, va, rsize, roff))
    return out


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    with open(sys.argv[1], "rb") as fh:
        data = fh.read()
    sec = next((s for s in sections(data) if s[0].lower() in (".rdata", "rdata")), None)
    if sec is None:
        print("section .rdata tidak ditemukan", file=sys.stderr)
        return 1
    _, _, _, rsize, roff = sec
    blob = data[roff:roff + rsize]
    strings = set()
    for m in re.finditer(rb"(?:[ -~]\x00){4,}", blob):
        try:
            strings.add(m.group().decode("utf-16le"))
        except UnicodeDecodeError:
            continue
    with open(sys.argv[2], "w", encoding="utf-8") as out:
        out.write("\n".join(sorted(strings)))
    print(f"section=.rdata rsize={rsize} unique_utf16={len(strings)} -> {sys.argv[2]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

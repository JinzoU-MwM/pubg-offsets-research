#!/usr/bin/env python3
"""Analisis PE + entropy + uji kompresi/XOR untuk binary PUBG terproteksi.

Pemakaian:
    python3 analyze_binary.py TslGame.exe
    python3 analyze_binary.py TslGame.exe --strings out.txt
"""
import argparse
import collections
import math
import re
import struct
import sys
import zlib


def entropy(buf: bytes) -> float:
    if not buf:
        return 0.0
    counts = collections.Counter(buf)
    n = len(buf)
    return -sum((v / n) * math.log2(v / n) for v in counts.values())


def parse_sections(data: bytes):
    if data[:2] != b"MZ":
        raise ValueError("bukan file MZ/PE")
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe:pe + 4] != b"PE\x00\x00":
        raise ValueError("signature PE tidak ditemukan")
    machine, nsec = struct.unpack_from("<HH", data, pe + 4)
    opt_size = struct.unpack_from("<H", data, pe + 20)[0]
    opt = pe + 24
    magic = struct.unpack_from("<H", data, opt)[0]
    ep = struct.unpack_from("<I", data, opt + 16)[0]
    image_base = struct.unpack_from("<Q", data, opt + 24)[0] if magic == 0x20B else struct.unpack_from("<I", data, opt + 28)[0]
    size_image = struct.unpack_from("<I", data, opt + 56)[0]
    sections = []
    so = opt + opt_size
    for i in range(nsec):
        off = so + i * 40
        raw_name = data[off:off + 8].rstrip(b"\x00")
        name = raw_name.decode("latin1", "replace")
        vsize, va, rsize, roff = struct.unpack_from("<IIII", data, off + 8)
        sections.append({"name": name, "vsize": vsize, "va": va, "rsize": rsize, "roff": roff})
    return {"machine": machine, "nsec": nsec, "ep": ep, "image_base": image_base,
            "size_image": size_image, "sections": sections}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--strings", help="tulis string UTF-16 (>=4 char) dari section yang ada ke file ini")
    ap.add_argument("--string-section", default=None, help="nama section sumber string (default: rdata pertama)")
    args = ap.parse_args()

    with open(args.file, "rb") as fh:
        data = fh.read()
    info = parse_sections(data)
    print(f"file={args.file} size={len(data)} machine=0x{info['machine']:x} "
          f"nsec={info['nsec']} ep_rva=0x{info['ep']:x} "
          f"image_base=0x{info['image_base']:x} size_image=0x{info['size_image']:x}")
    for s in info["sections"]:
        chunk = data[s["roff"]:s["roff"] + min(s["rsize"], 1 << 20)] if s["rsize"] else b""
        print(f"  {s['name'][:10]:10} va=0x{s['va']:<9x} vsz=0x{s['vsize']:<9x} "
              f"rsz=0x{s['rsize']:<9x} ent={entropy(chunk):.3f}")

    target = args.string_section
    if target is None:
        for s in info["sections"]:
            if s["name"].lower() in ("rdata", ".rdata"):
                target = s["name"]
                break
    if args.strings:
        src = next((s for s in info["sections"] if s["name"] == target), None)
        if src is None:
            print(f"section {target!r} tidak ditemukan", file=sys.stderr)
            return 1
        blob = data[src["roff"]:src["roff"] + src["rsize"]]
        found = set()
        for m in re.finditer(rb"(?:[ -~]\x00){4,}", blob):
            try:
                found.add(m.group().decode("utf-16le"))
            except UnicodeDecodeError:
                continue
        with open(args.strings, "w", encoding="utf-8") as out:
            out.write("\n".join(sorted(found)))
        print(f"utf16_strings={len(found)} -> {args.strings}")

    seq = b""
    for s in info["sections"]:
        if s["name"].lower() == ".text":
            seq = data[s["roff"]:s["roff"] + (1 << 20)]
            break
    if seq:
        tests = {
            "raw_deflate": lambda b: zlib.decompressobj(-15).decompress(b),
            "zlib": lambda b: zlib.decompressobj(15).decompress(b),
        }
        for name, fn in tests.items():
            try:
                out = fn(seq)
                print(f"  {name}: {len(out)} bytes")
            except Exception as exc:  # noqa: BLE001 - diagnostik
                print(f"  {name}: FAIL {exc}")
        sub = seq[:0x8000]

        def ic(buf: bytes) -> float:
            counts = collections.Counter(buf)
            n = len(buf)
            return sum(v * (v - 1) for v in counts.values()) / (n * (n - 1)) if n > 1 else 0.0

        base_ic = ic(sub)
        deltas = []
        for shift in list(range(1, 64)) + [128, 256, 512, 1024]:
            if len(seq) <= shift + len(sub):
                continue
            xored = bytes(a ^ b for a, b in zip(sub, seq[shift:shift + len(sub)]))
            deltas.append((ic(xored), shift))
        top = sorted(deltas, reverse=True)[:5]
        print(f"  ic_base={base_ic:.5f} top_ic=" + ", ".join(f"{v:.5f}@{s}" for v, s in top))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

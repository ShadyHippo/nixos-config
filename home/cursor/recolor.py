#!/usr/bin/env python3
"""Recolor the Bibata-Modern-Classic cursor theme.

Usage:  python3 recolor.py FILL OUTLINE

  FILL    color for the cursor body (was black)    e.g. #ff2b6d
  OUTLINE color for the cursor border (was white)  e.g. #b8bb26

Anti-aliased grays fade smoothly between the two (lerp by coverage).

Operates in place on ./Bibata-Modern-Classic/cursors.  Symlinks are
left untouched; only real container files are rewritten.  To regenerate
from scratch, re-copy the pristine theme from the nixpkgs
`bibata-cursors` package output first:

  cp -a /nix/store/<...>-bibata-cursors-2.0.7/share/icons/Bibata-Modern-Classic \
        ./Bibata-Modern-Classic
  chmod -R u+w ./Bibata-Modern-Classic

Format note: these files are Xcursor v1 containers written little-endian.
Each consists of a 16-byte header, a TOC (12 bytes per entry:
type/subtype/position), then one chunk per entry.  Chunk = 12-byte chunk
header + payload.  IMAGE chunks (type 0xfffd0002) carry a raw
XcursorImage struct: 6 little-endian u32 (size, width, height, xhot,
yhot, delay) followed by width*height premultiplied ARGB pixels.
This script copies the header/TOC/chunk bytes verbatim and only rewrites
the pixel area, so the file dialect stays whatever upstream produced.
"""

import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
THEME_DIR = os.path.join(HERE, "Bibata-Modern-Classic", "cursors")

IMAGE_TYPE = 0xFFFD0002


def parse_hex(s):
    s = s.strip().lstrip("#")
    if len(s) != 6:
        sys.exit(f"bad color {s!r}: expected #rrggbb")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def coverage(pixel, premul):
    """How white (1.0) vs black (0.0) is this pixel, alpha-aware."""
    a = (pixel >> 24) & 0xFF
    r = (pixel >> 16) & 0xFF
    g = (pixel >> 8) & 0xFF
    b = pixel & 0xFF
    if a == 0:
        return None
    if premul:
        # premultiplied: r,g,b <= a; divide by alpha to get color ratios
        return (r + g + b) / (3 * a)
    return (r + g + b) / 765


def recolor_payload(payload, fill, outline):
    w, h = struct.unpack_from("<II", payload, 4)
    n = w * h
    body = payload[24:]
    assert len(body) == n * 4, f"pixel data {len(body)} != {n * 4} (w={w} h={h})"
    pixels = list(struct.unpack(f"<{n}I", body))

    premul = True
    for p in pixels:
        a = (p >> 24) & 0xFF
        if ((p >> 16) & 0xFF) > a or ((p >> 8) & 0xFF) > a or (p & 0xFF) > a:
            premul = False
            break

    out = []
    for p in pixels:
        a = (p >> 24) & 0xFF
        t = coverage(p, premul)
        if t is None:
            out.append(p)  # fully transparent: keep as-is
            continue
        if premul:
            # blend coverage between fill(t=0) and outline(t=1), scaled by alpha
            r = round((fill[0] + t * (outline[0] - fill[0])) * a / 255)
            g = round((fill[1] + t * (outline[1] - fill[1])) * a / 255)
            b = round((fill[2] + t * (outline[2] - fill[2])) * a / 255)
        else:
            r = round(fill[0] + t * (outline[0] - fill[0]))
            g = round(fill[1] + t * (outline[1] - fill[1]))
            b = round(fill[2] + t * (outline[2] - fill[2]))
        out.append((a << 24) | (r << 16) | (g << 8) | b)

    return payload[:24] + struct.pack(f"<{n}I", *out)


def recolor_file(path, fill, outline):
    d = open(path, "rb").read()
    assert d[:4] == b"Xcur", f"{path}: not an Xcursor file"
    n = struct.unpack_from("<I", d, 12)[0]
    toc = [struct.unpack_from("<III", d, 16 + i * 12) for i in range(n)]

    chunks = []
    for i, (typ, sub, pos) in enumerate(toc):
        end = struct.unpack_from("<III", d, 16 + (i + 1) * 12)[2] if i + 1 < n else len(d)
        chunk = d[pos:pos + 12]
        payload = d[pos + 12:end]
        if typ == IMAGE_TYPE:
            payload = recolor_payload(payload, fill, outline)
        chunks.append((typ, sub, chunk, payload))

    newpos = 16 + n * 12
    out = bytearray(d[:16])
    for i, (typ, sub, chunk, payload) in enumerate(chunks):
        out += struct.pack("<III", typ, sub, newpos)
        newpos += 12 + len(payload)
    for typ, sub, chunk, payload in chunks:
        out += chunk + payload

    open(path, "wb").write(bytes(out))
    return len(chunks), sum(1 for c in chunks if c[0] == IMAGE_TYPE)


def main():
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} FILL OUTLINE   (e.g. #ff2b6d #b8bb26)")
    fill = parse_hex(sys.argv[1])
    outline = parse_hex(sys.argv[2])

    changed = total_chunks = total_images = 0
    for name in sorted(os.listdir(THEME_DIR)):
        p = os.path.join(THEME_DIR, name)
        if os.path.islink(p) or not os.path.isfile(p):
            continue  # leave symlinks; their targets are real files
        with open(p, "rb") as f:
            if f.read(4) != b"Xcur":
                continue
        n, k = recolor_file(p, fill, outline)
        changed += 1
        total_chunks += n
        total_images += k
    print(f"done: {changed} files recolored, {total_chunks} chunks, {total_images} images, "
          f"fill #{fill[0]:02x}{fill[1]:02x}{fill[2]:02x} / "
          f"outline #{outline[0]:02x}{outline[1]:02x}{outline[2]:02x}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
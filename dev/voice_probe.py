#!/usr/bin/env python3
"""Temporary probe for the voice-language feature (runs in GitHub Actions, where Riot's CDN is reachable).

It finds the live game manifest, downloads a few small voice-over WADs in two locales and checks that moving
/vo/<target>/ paths onto /vo/<current>/ reproduces the current locale's entries. Everything it learns goes to
<out>/probe-report.txt and the downloaded WADs are kept for local testing.
"""
import collections
import json
import os
import struct
import sys
import urllib.request

import xxhash
import zstandard

OUT = sys.argv[1]
HASHES = sys.argv[2] if len(sys.argv) > 2 else None
os.makedirs(OUT, exist_ok=True)
REPORT = open(os.path.join(OUT, "probe-report.txt"), "w")


def log(*parts):
    line = " ".join(str(p) for p in parts)
    print(line, flush=True)
    REPORT.write(line + "\n")
    REPORT.flush()


def http(url, headers=None):
    request = urllib.request.Request(url, headers={"User-Agent": "lolsikins-probe", **(headers or {})})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.status, response.read()


# 1. Live game manifest -----------------------------------------------------------------------------------------------
SIEVE = ("https://sieve.services.riotcdn.net/api/v1/products/lol/version-sets/EUW1"
         "?q[artifact_type_id]=lol-game-client&q[platform]=windows&q[published]=true")
status, sieve = http(SIEVE)
manifest_url = next(r["download"]["url"] for r in json.loads(sieve)["releases"]
                    if "lol-game-client" in r["release"]["labels"]["riot:artifact_type_id"]["values"])
log("manifest:", manifest_url)
status, raw = http(manifest_url)
magic, major, minor, flags, offset, compressed, manifest_id, uncompressed = struct.unpack_from("<4sBBHIIQI", raw, 0)
body = zstandard.ZstdDecompressor().stream_reader(raw[offset:offset + compressed], read_across_frames=True).read()
log("rman", major, minor, "body", len(body), "expected", uncompressed)
assert len(body) == uncompressed

# 2. FlatBuffer tables: 0 bundles, 1 languages, 2 files, 3 directories -----------------------------------------------
b = body
u8 = lambda o: b[o]
u32 = lambda o: struct.unpack_from("<I", b, o)[0]
i32 = lambda o: struct.unpack_from("<i", b, o)[0]
u64 = lambda o: struct.unpack_from("<Q", b, o)[0]
u16 = lambda o: struct.unpack_from("<H", b, o)[0]


def table(pos):
    vt = pos - i32(pos)
    return pos, [u16(vt + 4 + 2 * i) for i in range((u16(vt) - 4) // 2)]


def fld(t, i):
    pos, f = t
    return pos + f[i] if i < len(f) and f[i] else None


def tables(t, i):
    at = fld(t, i)
    if at is None:
        return []
    v = at + u32(at)
    return [table(v + 4 + 4 * k + u32(v + 4 + 4 * k)) for k in range(u32(v))]


def string(t, i):
    at = fld(t, i)
    if at is None:
        return ""
    s = at + u32(at)
    return b[s + 4:s + 4 + u32(s)].decode()


def u64s(t, i):
    at = fld(t, i)
    if at is None:
        return []
    v = at + u32(at)
    return [u64(v + 4 + 8 * k) for k in range(u32(v))]


opt = lambda t, i, read: read(fld(t, i)) if fld(t, i) is not None else 0
root = table(u32(0))
chunk_index = {}
for bundle in tables(root, 0):
    bundle_id, position = opt(bundle, 0, u64), 0
    for chunk in tables(bundle, 1):
        csize, usize = opt(chunk, 1, u32), opt(chunk, 2, u32)
        chunk_index[opt(chunk, 0, u64)] = (bundle_id, position, csize, usize)
        position += csize
dirs = {opt(t, 0, u64): (string(t, 2), opt(t, 1, u64)) for t in tables(root, 3)}


def dir_path(d):
    parts = []
    while d:
        name, d = dirs[d]
        parts.append(name)
    return "/".join(reversed(parts))


files = {}
for t in tables(root, 2):
    directory = dir_path(opt(t, 1, u64))
    files[f"{directory}/{string(t, 3)}" if directory else string(t, 3)] = (opt(t, 2, u32), u64s(t, 7))
log("files", len(files), "chunks", len(chunk_index))

# 3. Download a few small voice WADs in two locales ------------------------------------------------------------------
bundle_base = manifest_url.rsplit("/releases/", 1)[0] + "/bundles/"


def download(path):
    size, chunk_ids = files[path]
    runs = []
    for chunk_id in chunk_ids:
        bundle_id, position, csize, usize = chunk_index[chunk_id]
        if runs and runs[-1][0] == bundle_id and runs[-1][1] + runs[-1][2] == position:
            runs[-1][2] += csize
            runs[-1][3].append((csize, usize))
        else:
            runs.append([bundle_id, position, csize, [(csize, usize)]])
    out = bytearray()
    for bundle_id, position, length, chunks in runs:
        status, data = http(f"{bundle_base}{bundle_id:016X}.bundle",
                            {"Range": f"bytes={position}-{position + length - 1}"})
        assert len(data) == length, (status, len(data), length)
        cursor = 0
        for csize, usize in chunks:
            out += zstandard.ZstdDecompressor().decompress(data[cursor:cursor + csize], max_output_size=usize)
            cursor += csize
    assert len(out) == size, (len(out), size)
    log("  downloaded", path, size, "bytes in", len(runs), "range requests")
    return bytes(out)


def wad_entries(data):
    magic, major, minor = struct.unpack_from("<2sBB", data, 0)
    assert magic == b"RW", magic
    count = struct.unpack_from("<I", data, 268)[0]
    return (major, minor), [struct.unpack_from("<QIIIB", data, 272 + 32 * i) for i in range(count)]


paths = {}
if HASHES:
    for line in open(HASHES, encoding="utf-8", errors="replace"):
        h, _, p = line.rstrip("\n").partition(" ")
        paths[int(h, 16)] = p
    log("vo hashes:", len(paths))

for folder, name in [("Champions", "Alistar"), ("Champions", "Zilean"), ("Champions", "Talon"),
                     ("Maps/Shipping", "Common")]:
    pair = {}
    for locale in ("ja_JP", "en_US"):
        path = f"DATA/FINAL/{folder}/{name}.{locale}.wad.client"
        data = download(path)
        open(os.path.join(OUT, f"{name}.{locale}.wad.client"), "wb").write(data)
        pair[locale] = data
    ja_version, ja = wad_entries(pair["ja_JP"])
    en_version, en = wad_entries(pair["en_US"])
    en_hashes = {e[0] for e in en}
    known = matched = 0
    unknown = []
    for entry in ja:
        path = paths.get(entry[0])
        if path is None:
            unknown.append(entry)
            continue
        known += 1
        if xxhash.xxh64_intdigest(path.replace("/vo/ja_jp/", "/vo/en_us/")) in en_hashes:
            matched += 1
        else:
            log("   no en_US counterpart:", path)
    log(f"{name}: wad {ja_version}/{en_version}, ja entries {len(ja)} (known {known}, remapped {matched}), "
        f"en entries {len(en)}, types {dict(collections.Counter(e[4] & 15 for e in ja))}")
    for entry in unknown[:5]:
        log(f"   unknown ja entry {entry[0]:016x} size {entry[3]} type {entry[4] & 15}")
    for entry in ja[:4]:
        log(f"   ja {entry[0]:016x} {paths.get(entry[0], '?')}")
log("done")

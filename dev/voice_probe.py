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


def toc(path):
    """Download only the start of a WAD, enough to read its table of contents."""
    size, chunk_ids = files[path]
    data = bytearray()
    for chunk_id in chunk_ids:
        bundle_id, position, csize, usize = chunk_index[chunk_id]
        status, raw_chunk = http(f"{bundle_base}{bundle_id:016X}.bundle",
                                 {"Range": f"bytes={position}-{position + csize - 1}"})
        data += zstandard.ZstdDecompressor().decompress(raw_chunk, max_output_size=usize)
        if len(data) >= 272 and len(data) >= 272 + 32 * struct.unpack_from("<I", data, 268)[0]:
            break
    return wad_entries(bytes(data))


paths = {}
if HASHES:
    for line in open(HASHES, encoding="utf-8", errors="replace"):
        h, _, p = line.rstrip("\n").partition(" ")
        paths[int(h, 16)] = p
    log("vo hashes:", len(paths))

MODE = os.environ.get("PROBE_MODE", "compare")
if MODE == "classify":
    # What do the non-champion locale WADs hold besides voice-over? Needs the full hash list.
    every = {}
    for line in open(os.environ["ALL_HASHES"], encoding="utf-8", errors="replace"):
        h, _, p = line.rstrip("\n").partition(" ")
        every[int(h, 16)] = p
    log("all hashes:", len(every))
    for path in sorted(p for p in files if p.endswith(".ja_JP.wad.client") and "/Champions/" not in p):
        _, entries = toc(path)
        kinds = collections.Counter()
        samples = collections.defaultdict(list)
        for e in entries:
            known = every.get(e[0])
            kind = "unknown" if known is None else ("vo" if "/vo/" in known else known.split("/")[0] + "/" + (known.split("/")[1] if "/" in known else ""))
            kinds[kind] += 1
            if len(samples[kind]) < 3:
                samples[kind].append(known or f"{e[0]:016x}")
        log(f"{path}: {len(entries)} entries {dict(kinds)}")
        for kind, items in samples.items():
            log(f"   {kind}: {items}")
    # Raw compressed bundle ranges of one small file, to test the downloader offline.
    size, chunk_ids = files["DATA/FINAL/Champions/Alistar.ja_JP.wad.client"]
    for chunk_id in chunk_ids:
        bundle_id, position, csize, usize = chunk_index[chunk_id]
        status, data = http(f"{bundle_base}{bundle_id:016X}.bundle", {"Range": f"bytes={position}-{position + csize - 1}"})
        open(os.path.join(OUT, f"raw-{bundle_id:016X}-{position}.bin"), "wb").write(data)
    log("saved raw ranges for Alistar.ja_JP:", len(chunk_ids))
    log("done")
    sys.exit(0)

# Do the target locale's WADs use the same entry paths (hashes) as the current locale's? Then a voice pack is the
# target WAD renamed to the current locale, no path changes needed.
types = collections.Counter()
same = subset = differ = 0
locale_paths = collections.Counter()
pairs = sorted({p.rsplit(".", 3)[0] for p in files if p.endswith(".ja_JP.wad.client")})
for base in pairs:
    for other in ("en_US", "tr_TR"):
        if f"{base}.{other}.wad.client" not in files:
            continue
        _, ja = toc(f"{base}.ja_JP.wad.client")
        _, cur = toc(f"{base}.{other}.wad.client")
        ja_set, cur_set = {e[0] for e in ja}, {e[0] for e in cur}
        types.update(e[4] & 15 for e in ja)
        for e in ja:
            p = paths.get(e[0], "?")
            locale_paths[p.split("/vo/")[1].split("/")[0] if "/vo/" in p else ("unknown" if p == "?" else "other")] += 1
        if ja_set == cur_set:
            same += 1
        elif ja_set <= cur_set:
            subset += 1
        else:
            differ += 1
            log(f"  {base} ja vs {other}: only in ja {len(ja_set - cur_set)}, only in {other} {len(cur_set - ja_set)}")
log(f"pairs compared: same hashes {same}, ja subset {subset}, differ {differ}")
log("ja entry types:", dict(types))
log("ja entry path locale folders:", dict(locale_paths))
log("done")

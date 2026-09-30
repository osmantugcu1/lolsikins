#!/usr/bin/env python3
"""Temporary probe for the voice-language feature (runs in GitHub Actions, where Riot's CDN is reachable).

It finds the live game manifest, parses it, reports which locales ship voice-over WADs and how big they are,
downloads one champion's WAD in two locales and checks that moving /vo/<target>/ paths onto /vo/<current>/
reproduces the current locale's entries. Everything it learns goes to <out>/probe-report.txt.
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


# 1. Find the live game manifest --------------------------------------------------------------------------------
SIEVE = "https://sieve.services.riotcdn.net/api/v1/products/lol/version-sets/{region}?q[platform]=windows&q[published]=true"
manifest_url = None
for region in ["EUW1", "TR1", "NA1"]:
    url = SIEVE.format(region=region)
    try:
        status, body = http(url)
    except Exception as error:
        log("sieve", region, "failed:", error)
        continue
    open(os.path.join(OUT, f"sieve-{region}.json"), "wb").write(body)
    data = json.loads(body)
    log("sieve", region, status, "top-level keys:", list(data.keys()))
    for release in data.get("releases", []):
        labels = release.get("release", {}).get("labels", {})
        kind = labels.get("riot:artifact_type_id", {}).get("values", [])
        version = labels.get("riot:artifact_version_id", {}).get("values", [])
        url_ = release.get("download", {}).get("url")
        log("  release", kind, version, url_)
        if "lol-game-client" in kind and manifest_url is None:
            manifest_url = url_
if not manifest_url:
    log("no lol-game-client manifest found")
    sys.exit(1)
log("manifest:", manifest_url)

status, raw = http(manifest_url)
open(os.path.join(OUT, "game.manifest"), "wb").write(raw)
log("manifest bytes:", len(raw))

# 2. Parse RMAN ------------------------------------------------------------------------------------------------------
magic, major, minor, flags, offset, compressed, manifest_id, uncompressed = struct.unpack_from("<4sBBHIIQI", raw, 0)
log("rman header:", magic, major, minor, hex(flags), offset, compressed, hex(manifest_id), uncompressed)
body = zstandard.ZstdDecompressor().decompress(raw[offset:offset + compressed], max_output_size=uncompressed)
open(os.path.join(OUT, "game.manifest.body"), "wb").write(body)


class FlatBuffer:
    def __init__(self, data):
        self.b = data

    def u8(self, o): return self.b[o]
    def u16(self, o): return struct.unpack_from("<H", self.b, o)[0]
    def u32(self, o): return struct.unpack_from("<I", self.b, o)[0]
    def i32(self, o): return struct.unpack_from("<i", self.b, o)[0]
    def u64(self, o): return struct.unpack_from("<Q", self.b, o)[0]
    def deref(self, o): return o + self.u32(o)

    def table(self, pos):
        vtable = pos - self.i32(pos)
        count = (self.u16(vtable) - 4) // 2
        return pos, [self.u16(vtable + 4 + 2 * i) for i in range(count)]

    def field(self, table, index):
        pos, fields = table
        return pos + fields[index] if index < len(fields) and fields[index] else None

    def tables(self, table, index):
        at = self.field(table, index)
        if at is None:
            return []
        vec = self.deref(at)
        return [self.table(self.deref(vec + 4 + 4 * i)) for i in range(self.u32(vec))]

    def scalar(self, table, index, kind, default=0):
        at = self.field(table, index)
        return default if at is None else struct.unpack_from(kind, self.b, at)[0]

    def string(self, table, index):
        at = self.field(table, index)
        if at is None:
            return ""
        s = self.deref(at)
        return self.b[s + 4:s + 4 + self.u32(s)].decode("utf-8")

    def u64s(self, table, index):
        at = self.field(table, index)
        if at is None:
            return []
        vec = self.deref(at)
        return [self.u64(vec + 4 + 8 * i) for i in range(self.u32(vec))]


fb = FlatBuffer(body)
root = fb.table(fb.deref(0))
log("root fields:", len(root[1]), root[1])

bundles = fb.tables(root, 0)
languages = fb.tables(root, 1)
files = fb.tables(root, 2)
directories = fb.tables(root, 3)
log("counts: bundles", len(bundles), "languages", len(languages), "files", len(files), "directories", len(directories))
log("vtable sizes: bundle", len(bundles[0][1]), "language", len(languages[0][1]), "file", len(files[0][1]),
    "directory", len(directories[0][1]))

chunk_index = {}
for bundle in bundles:
    bundle_id = fb.scalar(bundle, 0, "<Q")
    position = 0
    for chunk in fb.tables(bundle, 1):
        chunk_id = fb.scalar(chunk, 0, "<Q")
        csize = fb.scalar(chunk, 1, "<I")
        usize = fb.scalar(chunk, 2, "<I")
        chunk_index[chunk_id] = (bundle_id, position, csize, usize)
        position += csize
log("chunks:", len(chunk_index))

language_names = {}
for language in languages:
    language_names[fb.scalar(language, 0, "<B")] = fb.string(language, 1)
log("languages:", sorted(language_names.items()))

dirs = {}
for directory in directories:
    dirs[fb.scalar(directory, 0, "<Q")] = (fb.string(directory, 2), fb.scalar(directory, 1, "<Q"))


def dir_path(directory_id):
    parts = []
    while directory_id in dirs and directory_id != 0:
        name, parent = dirs[directory_id]
        if name:
            parts.append(name)
        if parent == directory_id:
            break
        directory_id = parent
    return "/".join(reversed(parts))


entries = {}
for f in files:
    name = fb.string(f, 3)
    directory = dir_path(fb.scalar(f, 1, "<Q"))
    path = f"{directory}/{name}" if directory else name
    locale_bits = fb.scalar(f, 4, "<Q")
    locales = [language_names.get(i + 1, f"#{i + 1}") for i in range(64) if locale_bits >> i & 1]
    entries[path] = {"size": fb.scalar(f, 2, "<I"), "locales": locales, "chunks": fb.u64s(f, 7)}
log("sample files:")
for path in list(entries)[:8]:
    log("  ", path, entries[path]["size"], entries[path]["locales"], len(entries[path]["chunks"]))

# 3. Voice-over WADs per locale --------------------------------------------------------------------------------------
per_locale = collections.defaultdict(lambda: [0, 0])
per_folder = collections.defaultdict(lambda: [0, 0])
for path, entry in entries.items():
    parts = path.split("/")[-1].split(".")
    if len(parts) >= 4 and path.endswith(".wad.client") and "_" in parts[-3]:
        locale = parts[-3]
        per_locale[locale][0] += 1
        per_locale[locale][1] += entry["size"]
        folder = "/".join(path.split("/")[:-1])
        per_folder[(locale, folder)][0] += 1
        per_folder[(locale, folder)][1] += entry["size"]
log("locale WADs (count, MB):")
for locale, (count, size) in sorted(per_locale.items()):
    log(f"  {locale}: {count} files, {size / 1e6:.0f} MB")
log("ja_JP by folder:")
for (locale, folder), (count, size) in sorted(per_folder.items()):
    if locale == "ja_JP":
        log(f"  {folder}: {count} files, {size / 1e6:.0f} MB")

# 4. Download one champion in two locales -----------------------------------------------------------------------------
bundle_base = manifest_url.rsplit("/releases/", 1)[0] + "/bundles/"


def download(path):
    entry = entries[path]
    out = bytearray()
    runs = []
    for chunk_id in entry["chunks"]:
        bundle_id, position, csize, usize = chunk_index[chunk_id]
        if runs and runs[-1][0] == bundle_id and runs[-1][1] + runs[-1][2] == position:
            runs[-1][2] += csize
            runs[-1][3].append((csize, usize))
        else:
            runs.append([bundle_id, position, csize, [(csize, usize)]])
    for bundle_id, position, length, chunks in runs:
        url = f"{bundle_base}{bundle_id:016X}.bundle"
        status, data = http(url, {"Range": f"bytes={position}-{position + length - 1}"})
        cursor = 0
        for csize, usize in chunks:
            out += zstandard.ZstdDecompressor().decompress(data[cursor:cursor + csize], max_output_size=usize)
            cursor += csize
    assert len(out) == entry["size"], (len(out), entry["size"])
    return bytes(out)


targets = [p for p in entries if p.endswith("/Ahri.ja_JP.wad.client") or p.endswith("/Ahri.en_US.wad.client")]
log("downloading:", targets)
wads = {}
for path in targets:
    data = download(path)
    name = path.split("/")[-1]
    open(os.path.join(OUT, name), "wb").write(data)
    wads[name] = data
    log("  ", name, len(data), "bytes")

# 5. WAD entries and remap check ------------------------------------------------------------------------------------


def wad_entries(data):
    magic, major, minor = struct.unpack_from("<2sBB", data, 0)
    assert magic == b"RW", magic
    count = struct.unpack_from("<I", data, 4 + 256 + 8)[0]
    base = 4 + 256 + 8 + 4
    result = []
    for i in range(count):
        path_hash, offset, csize, usize, kind = struct.unpack_from("<QIIIB", data, base + 32 * i)
        result.append((path_hash, offset, csize, usize, kind & 15))
    return (major, minor), result


paths = {}
if HASHES:
    for line in open(HASHES, encoding="utf-8", errors="replace"):
        if "/vo/" in line:
            h, _, p = line.rstrip("\n").partition(" ")
            paths[int(h, 16)] = p
    log("vo hashes loaded:", len(paths))

if "Ahri.ja_JP.wad.client" in wads and "Ahri.en_US.wad.client" in wads:
    ja_version, ja = wad_entries(wads["Ahri.ja_JP.wad.client"])
    en_version, en = wad_entries(wads["Ahri.en_US.wad.client"])
    log("wad versions:", ja_version, en_version, "entries:", len(ja), len(en))
    en_hashes = {e[0] for e in en}
    known = unknown = matched = 0
    kinds = collections.Counter(e[4] for e in ja)
    log("ja entry types:", dict(kinds))
    for path_hash, _, csize, usize, kind in ja:
        path = paths.get(path_hash)
        if path is None:
            unknown += 1
            continue
        known += 1
        moved = path.replace("/vo/ja_jp/", "/vo/en_us/")
        if xxhash.xxh64_intdigest(moved.lower()) in en_hashes:
            matched += 1
        else:
            log("   no en_US counterpart:", path)
    log(f"ja entries: known {known}, unknown {unknown}, remapped onto an en_US entry {matched}")
    for path_hash, *_ in ja[:12]:
        log("   ja:", f"{path_hash:016x}", paths.get(path_hash, "?"))
    en_known = sum(1 for e in en if e[0] in paths)
    log(f"en entries with known paths: {en_known} / {len(en)}")
log("done")

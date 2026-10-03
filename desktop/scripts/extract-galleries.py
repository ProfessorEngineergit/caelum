#!/usr/bin/env python3
"""Regenerates src/main/galleries.json from the macOS app's curated galleries
(Sources/Caelum/Core/Sources/StaticGallerySource.swift), so both apps show the
same hand-picked imagery. Run from anywhere: python3 desktop/scripts/extract-galleries.py"""
import json, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SWIFT = ROOT / "Sources/Caelum/Core/Sources/StaticGallerySource.swift"
OUT = ROOT / "desktop/src/main/galleries.json"

STR = r'"((?:[^"\\]|\\.)*)"'
RES = {"uhd": "4K", "hd": "HD", "sd": "SD"}


def unescape(s):
    return s.encode().decode("unicode_escape").encode("latin-1").decode("utf-8")


def args(block):
    out = {k: unescape(v) for k, v in re.findall(r'(\w+):\s*' + STR, block)}
    m = re.search(r'resolution:\s*\.(\w+)', block)
    out["resolution"] = RES[m.group(1)] if m else "4K"
    return out


src = SWIFT.read_text()
galleries = []
for m in re.finditer(r'static let \w+ = StaticGallerySource\((.*?)\n        \]\)\n', src, re.S):
    body = m.group(1)
    head = args(body.split("assets:")[0])
    accent = re.search(r'accentHex:\s*0x([0-9A-Fa-f]+)', body).group(1)
    assets = []
    for block in re.findall(r'\.init\((.*?)\)(?=,?\s*(?://[^\n]*\s*)*(?:\.init|\]|$))', body, re.S):
        a = args(block)
        if "nasaID" in a:
            nid = a["nasaID"]
            base = f"https://images-assets.nasa.gov/image/{nid}/{nid}"
            a = {"identifier": nid, "title": a["title"], "credit": a["credit"],
                 "explanation": a["explanation"], "imageURL": base + "~orig.jpg",
                 "thumbURL": base + "~medium.jpg",
                 "pageURL": f"https://images.nasa.gov/details/{nid}",
                 "date": a.get("dateString"), "resolution": a["resolution"]}
        else:
            a["date"] = a.pop("dateString", None)
        assets.append(a)
    galleries.append({"id": head["id"], "name": head["name"], "subtitle": head["subtitle"],
                      "accent": "#" + accent.upper(), "assets": assets})

OUT.write_text(json.dumps(galleries, indent=1, ensure_ascii=False) + "\n")
print(f"{OUT.relative_to(ROOT)}: {len(galleries)} galleries, "
      f"{sum(len(g['assets']) for g in galleries)} images")

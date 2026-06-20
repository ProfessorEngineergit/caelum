# Caelum — Image-Curation Brief (paste this into a fresh coding session)

> **How to use:** Open a new Claude Code / "Coding" session **with its working
> directory set to the Caelum repo** (`/Users/bahriannovotny/Desktop/DEV./caelum`)
> and paste everything below the line into the first message. The agent will only
> *find and verify* image URLs and print ready-to-paste Swift blocks. **You** copy
> those blocks into the app. The agent must not change any app code.

---

## ROLE

You are an image-sourcing assistant for **Caelum**, a macOS app that sets
high-resolution space imagery as the desktop wallpaper. Your only job is to find
**maximum-resolution, razor-sharp, directly-hotlinkable image URLs**, verify each
one, and output them as copy-paste-ready Swift `Asset` blocks grouped by category.

**Hard constraints — do NOT break these:**
- **Do not edit, move, or create any source file.** Read-only on the codebase.
- **Do not run, build, or launch the app.**
- Your entire deliverable is **one Markdown report** printed in chat (or written to
  `CURATION-RESULTS.md` at the repo root if asked) containing verified `.init(...)`
  blocks. Nothing else.
- **Every URL you output must be verified by you** (see *Verification*). Never guess
  a URL or include one you could not load. No dead links, no HTML pages, no thumbnails
  passed off as full-res.

---

## WHERE THINGS LIVE

- Repo root: `/Users/bahriannovotny/Desktop/DEV./caelum`
- The **only** file these images feed into (read it to learn the exact format,
  do not edit it):
  `Sources/Caelum/Core/Sources/StaticGallerySource.swift`
- Each category is a `static let` of `StaticGallerySource` holding an `assets: [Asset]`
  array. You are producing replacement / additional `Asset` entries for those arrays.

### The `Asset` model (two initializers)

**1 — NASA images.nasa.gov assets** (preferred for NASA; the URL is built for you
from the `nasaID`, resolving to the `~orig` maximum-resolution file):

```swift
.init(title: "Jupiter's Great Red Spot",
      nasaID: "PIA01384",
      credit: "NASA/JPL",
      explanation: "One sentence, factual, no hype.",
      dateString: "2024-07-18",   // optional, "yyyy-MM-dd"
      resolution: .uhd)           // .uhd | .hd | .sd
```
> Use this when the asset exists at `https://images.nasa.gov/details/<nasaID>`.
> The app turns `<nasaID>` into
> `https://images-assets.nasa.gov/image/<nasaID>/<nasaID>~orig.jpg`.
> **Verify that `~orig.jpg` URL yourself** before including the ID.

**2 — Any other source** (ESA/Hubble, ESO, esawebb, film stills, art, etc.) — you
supply the direct image URL:

```swift
.init(identifier: "deep-orion-neb-01",      // unique, kebab-case, stable
      title: "The Orion Nebula",
      credit: "NASA, ESA, M. Robberto et al.",
      explanation: "One factual sentence.",
      imageURL: "https://cdn.esahubble.org/archives/images/large/heic0601a.jpg",
      thumbURL: "https://cdn.esahubble.org/archives/images/screen/heic0601a.jpg", // optional but nice
      pageURL: "https://esahubble.org/images/heic0601a/",   // optional, source/attribution
      dateString: "2006-01-11",   // optional
      resolution: .uhd)
```

### `resolution` tag — pick by the image's real pixel width
- `.uhd` → **≥ 3840 px wide** (4K and up). **Aim for this on every asset.**
- `.hd`  → 1920–3839 px wide. Acceptable only if nothing larger exists.
- `.sd`  → below 1920 px. **Reject** — do not submit `.sd` assets.

---

## THE QUALITY BAR (this is the whole point of the task)

The current gallery has some weak spots — **the Sci-Fi category especially is soft /
washed-out** and needs replacing. For every asset you propose:

1. **Resolution:** ≥ 3840 px on the long edge. 5K–8K strongly preferred. Bigger is
   better — Caelum downsamples, it never upscales.
2. **Sharpness:** crisp, full detail. **Reject** anything blurry, heavily compressed,
   upscaled, banded, or noisy. If it looks soft at 100%, drop it.
3. **Direct & hotlinkable:** the URL must return the actual image bytes
   (`Content-Type: image/jpeg` or `image/png`), not an HTML gallery page, not a
   redirect to a login, not a thumbnail.
4. **Composition for a wallpaper:** striking, clean, ideally landscape, subject not
   jammed in a corner. No watermarks, no captions burned in, no UI chrome, no people
   posing / press-room photos.
5. **Attribution:** record an accurate `credit` and, when available, a `pageURL` to the
   source. Prefer public-domain / NASA / ESA / ESO / CC-licensed sources.

---

## WHAT TO FIND, PER CATEGORY

Target **8–10 verified assets per category** (replace weak existing ones, keep the
strong ones — they're listed so you don't duplicate). Note existing IDs to avoid
repeats.

### 1. `deep` — Deep Space (nebulae & galaxies)
Best of JWST + Hubble + ESO. Carina, Pillars, Orion, Andromeda, Tarantula, Sombrero,
Whirlpool, deep fields, Webb's deepest. Sources with reliable 4K+ originals:
`cdn.esawebb.org/archives/images/large/...`, `cdn.esahubble.org/archives/images/large/...`,
`eso.org/public/images/...` (use the **`/large/` or original `.tif`→`.jpg`** asset).
Already have: weic2205a, heic1509a, heic0611b, potm2605a, weic2609c.

### 2. `earth` — Earth from Space (orbit & lunar views, **no posed people**)
ISS Cupola Earth limbs, aurora from orbit, city-lights night passes, Blue Marble,
Earthrise/Earthset, Orion-window Earth. Prefer `images.nasa.gov` `iss…`/`art…` IDs at
`~orig`. Already have: iss071e456772, iss058e005282, iss074e0319988, art002e009288.

### 3. `solar` — Solar System (planets & moons, **max-res planetary**)
Cassini Saturn mosaics, Juno Jupiter, New Horizons Pluto, Voyager classics, Mars
(Valles Marineris / Curiosity vistas), Europa, Titan, Enceladus plumes. Mostly
`PIA…` IDs on images.nasa.gov. Already have: PIA01384, PIA19952, PIA17172, PIA21617,
PIA22946.

### 4. `stations` — Spacecraft (hardware & ships, **no posed crew**)
Orion approaching/leaving the Moon, ISS solar arrays / trusses, JWST renders, Dragon
& Starship on orbit, satellites deploying, Voyager/Cassini craft art. Already have:
iss074e0301636, iss074e0301064, art001e000269, art001e001713, art001e002186,
iss058e005282.

### 5. `interstellar` — **Sci-Fi (HIGHEST PRIORITY — current set is too soft)**
Display name "Sci-Fi", subtitle "Interstellar & beyond". Replace the soft 1440p
SceneStill frames with **sharp 4K material**:
- **Interstellar (2014):** find genuine **3840×2160+ UHD** frames — Gargantua, the
  Endurance, the Ranger, Miller's water world, the docking sequence, Mann's ice planet.
  Sources: 4K/UHD frame-grab galleries, film-still archives that serve true-4K, official
  press kits. Verify real pixel size — many "HD stills" are upscaled; reject those.
- **NASA "Visions of the Future" posters** (sci-fi travel art) — these are genuine 4K–5K
  and look great. Find the rest of the series at `~orig`. Already have: PIA22085,
  PIA22086, PIA22087.
- **Tasteful sci-fi / space concept art** at 4K+ (clean spacecraft, planetscapes,
  megastructures). Prefer CC-licensed / artist-permitted; always record `credit` +
  `pageURL`. No fan logos, no text overlays.
- Keep it astro-flavoured (ships, planets, black holes) — no character close-ups.
Existing (likely to be replaced): interstellar-023/027/035/036/040/070/073 (SceneStill, .hd).

---

## VERIFICATION (do this for EVERY url before you include it)

Run these from a shell. Include the measured numbers in a trailing `//` comment on each
asset so the numbers are auditable.

```bash
URL='https://…'

# 1) Header check — must be HTTP 200 and an image type; note the byte size.
curl -sIL "$URL" | grep -iE 'HTTP/|content-type|content-length'

# 2) Real pixel dimensions — download and measure (don't trust the page's claims).
curl -sL "$URL" -o /tmp/c.img && sips -g pixelWidth -g pixelHeight /tmp/c.img
```

Accept only if: status `200`, `content-type` is `image/jpeg`/`image/png`,
`pixelWidth ≥ 3840` (or ≥1920 and tagged `.hd` only when nothing bigger exists), and the
file is a real photo/render (open it if unsure — reject soft/upscaled).

For NASA `nasaID`s, verify the built original directly:
```bash
ID='PIA22085'
curl -sIL "https://images-assets.nasa.gov/image/$ID/$ID~orig.jpg" | grep -iE 'HTTP/|content-type|content-length'
```

---

## OUTPUT FORMAT (exactly this — nothing to install)

A Markdown report with **one fenced `swift` block per category**, each holding the
verified `Asset` initializers ready to drop straight into the matching `assets: [ … ]`
array in `StaticGallerySource.swift`. Example:

````markdown
### deep  (replace array contents)
```swift
.init(identifier: "deep-tarantula-jwst",
      title: "Tarantula Nebula",
      credit: "NASA, ESA, CSA, STScI",
      explanation: "Webb's near-infrared view of star-forming region 30 Doradus.",
      imageURL: "https://cdn.esawebb.org/archives/images/large/weic2212a.jpg",
      thumbURL: "https://cdn.esawebb.org/archives/images/screen/weic2212a.jpg",
      pageURL: "https://esawebb.org/images/weic2212a/",
      resolution: .uhd),   // verified 200 · image/jpeg · 6452×4640
```
````

End the report with a short **summary table**: category → count → min/median pixel width
of the assets you verified, so the quality bar is visible at a glance. That's it — the
user pastes the blocks in.

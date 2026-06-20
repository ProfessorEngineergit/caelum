# Caelum Image Curation Notes

This note explains the curated replacement images proposed for `StaticGallerySource.swift`.
No app source files were edited. The curation favors direct, hotlinkable JPEG URLs that were checked with `curl -sIL` and measured locally with `sips`.

## Verification Standard

Every included asset was required to return HTTP 200 with `Content-Type: image/jpeg` and to measure at least 3840 px wide, except no `.hd` fallbacks were used in the final proposed sets. The final report therefore uses only `.uhd` assets.

## Deep Space

The deep-space set keeps the strongest existing observatory anchors and adds large Webb/Hubble classics with cleaner wallpaper value.

| asset | why it was chosen | verified size |
|---|---|---:|
| `weic2205a` Cosmic Cliffs of Carina | Existing keeper; extremely large Webb landscape with strong star-forming structure. | 14575x8441 |
| `heic1509a` Pillars of Creation | Existing keeper; iconic Hubble target with sharp vertical dust columns. | 8919x6683 |
| `heic0611b` Hubble Ultra Deep Field | Existing keeper; dense galaxy field with high source credibility. | 6200x6200 |
| `weic2609c` A Little Red Dot | Existing keeper; deep Webb field with very high pixel count. | 11542x10860 |
| `weic2212a` Tarantula Nebula | New addition; vivid Webb star-forming region, 14K-wide source. | 14557x8418 |
| `weic2303a` Rho Ophiuchi Cloud Complex | New addition; Webb anniversary image with strong dust color and landscape framing. | 9474x4654 |
| `heic0601a` Orion Nebula | New addition; huge Hubble mosaic, excellent detail for downsampling. | 18000x18000 |
| `heic0506a` Whirlpool Galaxy | New addition; high-resolution spiral galaxy with strong wallpaper composition. | 11477x7965 |

## Earth From Space

The Earth set balances orbital photographs, lunar-perspective Artemis imagery, and clean global composites.

| asset | why it was chosen | verified size |
|---|---|---:|
| `iss071e456772` Moonlit Pacific from the ISS | Existing keeper; sharp ISS view with Moon glint, airglow, and stars. | 8256x5504 |
| `iss058e005282` Aurora from the Station | Existing keeper; solar arrays frame aurora and Earth's limb. | 5568x3712 |
| `iss074e0319988` Orbital Star Trails | Existing keeper; distinctive long-exposure ISS trail image. | 8256x5504 |
| `art002e009288` Earthset from Orion | Existing keeper; clean Orion lunar-perspective Earthset. | 5568x3712 |
| `PIA18033` Blue Marble 2012 | New addition; detailed full-disk Earth composite at 8000 px. | 8000x8000 |
| `GSFC_20171208_Archive_e001591` Black Marble | New addition; 8192 px night-Earth composite, replacing lower-res night candidates. | 8192x8192 |
| `art002e009280b` Artemis Era Earthrise | New addition; crescent Earth through Orion-window framing. | 5568x3712 |
| `iss029e012564` Aurora and City Lights | New addition; aurora plus night-side city lights from the ISS. | 4256x2832 |

## Solar System

The solar-system set keeps iconic planetary images but removes the weaker 3000 px Jupiter Marble in favor of all-UHD candidates.

| asset | why it was chosen | verified size |
|---|---|---:|
| `PIA01384` Jupiter's Great Red Spot | Existing keeper; Voyager classic, still above 5K wide. | 5489x4637 |
| `PIA19952` The Rich Colors of Pluto | Existing keeper; New Horizons enhanced-color global Pluto view. | 5000x5000 |
| `PIA17172` The Day the Earth Smiled | Existing keeper; panoramic Cassini Saturn mosaic. | 9000x3500 |
| `PIA21617` Saturn Noodle Mosaic | Existing keeper; Cassini Grand Finale mosaic at 5K. | 5001x5301 |
| `PIA21967` 95 Minutes Over Jupiter | New addition; 16K-wide JunoCam sequence with dramatic planetary sweep. | 16000x2952 |
| `PIA22939` Juno Captures Brown Barge | New addition; 6000 px Juno image processed from mission data. | 6000x3000 |
| `PIA26595` Turbulence in Jupiter's Atmosphere | New addition; recent 6.8K Juno cloudscape. | 6826x3840 |
| `PIA20727` Pluto's Twilight Zone | New addition; 5K New Horizons crescent/haze view. | 5000x7295 |

## Spacecraft

The spacecraft set removes the reused Earth/aurora item and focuses on hardware: CubeSats, Orion, Dragon, ISS arrays, Voyager, and Starship HLS concept art.

| asset | why it was chosen | verified size |
|---|---|---:|
| `iss074e0301636` CubeSats Deploy from the ISS | Existing keeper; sharp 8K operational spacecraft deployment. | 8256x5504 |
| `art001e000269` Orion Approaches the Moon | Existing keeper; Artemis I Orion hardware with lunar background. | 4000x3000 |
| `art001e001713` Orion Between Earth and Moon | Existing keeper; strong Orion solar-array geometry. | 4000x3000 |
| `art001e002186` Orion Looks Back at the Moon | Existing keeper; clean Artemis I lunar-distance view. | 4000x3000 |
| `iss048e042025` Dragon CRS-9 Approaches the ISS | New addition; real Dragon cargo spacecraft on orbital approach. | 4928x3280 |
| `iss073e0850593` Moonlit ISS Solar Arrays | New addition; 8K station hardware with unusual violet moonlit color. | 8256x5504 |
| `PIA17462` Voyager Enters Interstellar Space | New addition; 8K NASA/JPL spacecraft concept with interstellar theme. | 8192x4610 |
| `starship-hls-fuel-depot` Starship HLS Fuel Depot | New addition; direct encoded NASA Images URL for a 5K Starship HLS concept. | 5000x2619 |

## Sci-Fi

The Sci-Fi set replaces the soft SceneStill `interstellar-*` frames. I did not include unverified or rate-limited poster originals, and I avoided movie stills that could not be proven as true 4K direct images. The final mix uses verified NASA/JPL poster art plus verified 4K+ NASA/JPL science-fiction-adjacent concept art.

| asset | why it was chosen | verified size |
|---|---|---:|
| `visions-hd-40307g` HD 40307g Travel Poster | New replacement; high-resolution JPL travel-poster art with a super-Earth theme. | 8167x11775 |
| `visions-grand-tour` Grand Tour Travel Poster | New replacement; 6K JPL poster for outer-planet gravity-assist travel. | 6000x9000 |
| `visions-51-pegasi-b` 51 Pegasi b Travel Poster | New replacement; 8K JPL exoplanet poster with strong retro-future style. | 8175x11775 |
| `visions-kepler-186f` Kepler-186f Travel Poster | New replacement; 8K JPL exoplanet poster for an Earth-size habitable-zone world. | 8175x11775 |
| `PIA22085` Black Hole With Jet | New replacement; verified 5K NASA/JPL black-hole concept, useful as a sci-fi anchor. | 5120x2880 |
| `PIA14724` Where the Sun Sets Twice | New replacement; 8K circumbinary-planet concept with cinematic horizon composition. | 8000x6000 |
| `PIA21423` Surface of TRAPPIST-1f | New replacement; 4.5K exoplanet surface concept with visible neighboring planets. | 4534x2550 |
| `PIA19833` Hot, Rocky World | New replacement; 4.8K molten rocky exoplanet concept. | 4800x2700 |

## Summary

| category | count | min pixel width | median pixel width |
|---|---:|---:|---:|
| deep | 8 | 6200 | 11510 |
| earth | 8 | 4256 | 6784 |
| solar | 8 | 5000 | 5745 |
| stations | 8 | 4000 | 4964 |
| interstellar | 8 | 4534 | 7000 |

## Not Included

The SceneStill `interstellar-023/027/035/036/040/070/073` images were intentionally replaced because they are only `.hd` and appeared too soft for the category target. Several NASA/JPL Visions of the Future poster files were also excluded when the direct original URL did not return HTTP 200 image bytes during verification.

import Foundation

// MARK: - Shared types

struct CuratedItem: Decodable {
    let title: String
    let credit: String?
    let explanation: String?
    let image: String
    let thumb: String?
    let page: String?
    let date: String?
}

/// A parameterised curated-collection source. Primary data comes from a
/// JSON manifest served on GitHub Pages (updateable without an app release);
/// falls back to a curated set of verified, stable CDN URLs.
struct CuratedSource: ImageSource {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let accentHex: UInt32
    let typicalResolution: ResolutionHint
    let manifestURL: URL
    let embedded: [CuratedItem]

    func fetchRecent(limit: Int) async throws -> [CosmicImage] {
        let items = (try? await HTTPClient.json([CuratedItem].self, from: manifestURL)) ?? embedded
        let mapped = items.compactMap(map)
        guard !mapped.isEmpty else { throw SourceError.empty }
        return Array(mapped.shuffled().prefix(max(limit, 1)))
    }

    private func map(_ item: CuratedItem) -> CosmicImage? {
        guard let imageURL = URL(string: item.image) else { return nil }
        return CosmicImage(
            id: "\(id)-\(item.image)",
            title: item.title,
            credit: item.credit,
            explanation: item.explanation,
            date: item.date.flatMap { CaelumDates.ymd.date(from: $0) },
            sourceID: id,
            pageURL: item.page.flatMap(URL.init(string:)),
            imageURL: imageURL,
            thumbURL: item.thumb.flatMap(URL.init(string:)),
            isVideo: false,
            resolution: typicalResolution)
    }
}

// MARK: - The five curated collections

extension CuratedSource {

    // 1 · Deep Space — Webb/Hubble/ESO ultra-high-res (verified CDN URLs)
    static let deepSpace = CuratedSource(
        id: "curated-deep", name: "Deep Space", subtitle: "Nebulae & galaxies",
        symbol: "sparkles", accentHex: 0x5EE7FF, typicalResolution: .uhd,
        manifestURL: URL(string: "https://professorengineergit.github.io/caelum/curated-deep.json")!,
        embedded: [
            .init(title: "Cosmic Cliffs of Carina (JWST)",
                  credit: "NASA, ESA, CSA, STScI",
                  explanation: "The \"Cosmic Cliffs\" — towering peaks of gas and dust in NGC 3324 sculpted by the fierce radiation of hot young stars, imaged by the James Webb Space Telescope.",
                  image: "https://cdn.esawebb.org/archives/images/large/weic2205a.jpg",
                  thumb: "https://cdn.esawebb.org/archives/images/screen/weic2205a.jpg",
                  page: "https://esawebb.org/images/weic2205a/", date: nil),
            .init(title: "Pillars of Creation (JWST)",
                  credit: "NASA, ESA, CSA, STScI",
                  explanation: "JWST's near-infrared portrait of the iconic Pillars of Creation in M16 — towering columns of cool gas where new stars are born.",
                  image: "https://cdn.esawebb.org/archives/images/large/weic2216a.jpg",
                  thumb: "https://cdn.esawebb.org/archives/images/screen/weic2216a.jpg",
                  page: "https://esawebb.org/images/weic2216a/", date: nil),
            .init(title: "Pillars of Creation (Hubble)",
                  credit: "NASA, ESA, Hubble Heritage Team",
                  explanation: "Hubble's celebrated 2015 visible-light view of the Pillars of Creation — the image that defined a generation's picture of the cosmos.",
                  image: "https://cdn.esahubble.org/archives/images/large/heic1509a.jpg",
                  thumb: "https://cdn.esahubble.org/archives/images/screen/heic1509a.jpg",
                  page: "https://esahubble.org/images/heic1509a/", date: nil),
            .init(title: "The Milky Way over Paranal",
                  credit: "ESO / Y. Beletsky",
                  explanation: "The full arch of the Milky Way over ESO's Paranal Observatory in the Atacama Desert — one of Earth's darkest skies.",
                  image: "https://cdn.eso.org/images/large/eso0932a.jpg",
                  thumb: "https://cdn.eso.org/images/screen/eso0932a.jpg",
                  page: "https://www.eso.org/public/images/eso0932a/", date: nil),
            .init(title: "Journey to a Galaxy Cluster",
                  credit: "ESA/Hubble & NASA",
                  explanation: "Hubble peers into the heart of a rich galaxy cluster, recording thousands of galaxies spanning billions of light-years.",
                  image: "https://cdn.esahubble.org/archives/images/large/potm2605a.jpg",
                  thumb: "https://cdn.esahubble.org/archives/images/screen/potm2605a.jpg",
                  page: "https://esahubble.org/images/potm2605a/", date: nil),
            .init(title: "ESO Deep Field",
                  credit: "ESO",
                  explanation: "A deep-sky exposure from ESO's Very Large Telescope reveals thousands of faint galaxies in a tiny patch of sky.",
                  image: "https://cdn.eso.org/images/large/eso1907a.jpg",
                  thumb: "https://cdn.eso.org/images/screen/eso1907a.jpg",
                  page: "https://www.eso.org/public/images/eso1907a/", date: nil),
        ]
    )

    // 2 · Earth from Space — astronaut photography, full-disk Earth
    static let earthFromSpace = CuratedSource(
        id: "curated-earth", name: "Earth from Space", subtitle: "Our pale blue dot",
        symbol: "globe.americas.fill", accentHex: 0x5EF2B0, typicalResolution: .uhd,
        manifestURL: URL(string: "https://professorengineergit.github.io/caelum/curated-earth.json")!,
        embedded: [
            .init(title: "Earthrise (Apollo 8)",
                  credit: "NASA / Bill Anders",
                  explanation: "The Earth rising above the lunar horizon, photographed by Bill Anders during Apollo 8 on 24 December 1968. One of the most influential photographs ever taken.",
                  image: "https://images-assets.nasa.gov/image/as08-14-2383/as08-14-2383~large.jpg",
                  thumb: "https://images-assets.nasa.gov/image/as08-14-2383/as08-14-2383~small.jpg",
                  page: "https://images.nasa.gov/details/as08-14-2383", date: "1968-12-24"),
            .init(title: "The Blue Marble (Apollo 17)",
                  credit: "NASA / Apollo 17 crew",
                  explanation: "Photographed by the Apollo 17 crew on 7 December 1972, at 29,000 km from Earth's surface — the most reproduced photograph in history.",
                  image: "https://images-assets.nasa.gov/image/AS17-148-22727/AS17-148-22727~large.jpg",
                  thumb: "https://images-assets.nasa.gov/image/AS17-148-22727/AS17-148-22727~small.jpg",
                  page: "https://images.nasa.gov/details/AS17-148-22727", date: "1972-12-07"),
            .init(title: "Earth at Night — 'Black Marble'",
                  credit: "NASA Earth Observatory / Suomi NPP",
                  explanation: "A composite of Earth at night assembled from data acquired by the Suomi NPP satellite in 2012, showing the distribution of human civilisation.",
                  image: "https://images-assets.nasa.gov/image/GSFC_20171208_Archive_e000868/GSFC_20171208_Archive_e000868~large.jpg",
                  thumb: "https://images-assets.nasa.gov/image/GSFC_20171208_Archive_e000868/GSFC_20171208_Archive_e000868~small.jpg",
                  page: "https://earthobservatory.nasa.gov/images/79765/", date: nil),
            .init(title: "ISS Over the Atlantic",
                  credit: "NASA / ISS Expedition crew",
                  explanation: "The International Space Station passes over a vivid blue Atlantic Ocean, as captured by an ISS crew member.",
                  image: "https://images-assets.nasa.gov/image/iss068e028479/iss068e028479~large.jpg",
                  thumb: "https://images-assets.nasa.gov/image/iss068e028479/iss068e028479~small.jpg",
                  page: "https://images.nasa.gov/details/iss068e028479", date: nil),
            .init(title: "Hurricane Dorian from the ISS",
                  credit: "NASA / ESA / ISS",
                  explanation: "Category 5 Hurricane Dorian as seen from the International Space Station, its perfect spiral eye visible over the Bahamas in September 2019.",
                  image: "https://images-assets.nasa.gov/image/iss060e000701/iss060e000701~large.jpg",
                  thumb: "https://images-assets.nasa.gov/image/iss060e000701/iss060e000701~small.jpg",
                  page: "https://images.nasa.gov/details/iss060e000701", date: "2019-09-02"),
        ]
    )

    // 3 · Solar System — planets, moons, Sun (Cassini, Juno, MRO, Parker)
    static let solarSystem = CuratedSource(
        id: "curated-solar", name: "Solar System", subtitle: "Planets & moons",
        symbol: "sun.max.fill", accentHex: 0xFFD166, typicalResolution: .uhd,
        manifestURL: URL(string: "https://professorengineergit.github.io/caelum/curated-solar.json")!,
        embedded: [
            .init(title: "Saturn and Its Rings (Cassini)",
                  credit: "NASA / JPL-Caltech / Space Science Institute",
                  explanation: "Cassini captured this exquisite natural-colour view of Saturn's rings just before its Grand Finale in 2017 — the most detailed images ever taken of the gas giant.",
                  image: "https://images-assets.nasa.gov/image/PIA21046/PIA21046~large.jpg",
                  thumb: "https://images-assets.nasa.gov/image/PIA21046/PIA21046~small.jpg",
                  page: "https://images.nasa.gov/details/PIA21046", date: nil),
            .init(title: "Jupiter's Great Red Spot (Juno)",
                  credit: "NASA / JPL-Caltech / SwRI / MSSS",
                  explanation: "Juno's JunoCam imager captured Jupiter's iconic Great Red Spot — an anticyclonic storm wider than Earth that has raged for centuries.",
                  image: "https://images-assets.nasa.gov/image/PIA21775/PIA21775~large.jpg",
                  thumb: "https://images-assets.nasa.gov/image/PIA21775/PIA21775~small.jpg",
                  page: "https://images.nasa.gov/details/PIA21775", date: nil),
            .init(title: "Mars Valles Marineris (Viking)",
                  credit: "NASA / JPL / USGS",
                  explanation: "A mosaic of Viking Orbiter images shows the vast Valles Marineris canyon system stretching across the Martian equator — more than 4,000 km long.",
                  image: "https://images-assets.nasa.gov/image/PIA00653/PIA00653~large.jpg",
                  thumb: "https://images-assets.nasa.gov/image/PIA00653/PIA00653~small.jpg",
                  page: "https://images.nasa.gov/details/PIA00653", date: nil),
            .init(title: "Pluto in True Colour (New Horizons)",
                  credit: "NASA / JHUAPL / SwRI",
                  explanation: "New Horizons captured this true-colour image of Pluto just before its closest approach on 14 July 2015, revealing the iconic heart-shaped Tombaugh Regio.",
                  image: "https://images-assets.nasa.gov/image/PIA19952/PIA19952~large.jpg",
                  thumb: "https://images-assets.nasa.gov/image/PIA19952/PIA19952~small.jpg",
                  page: "https://images.nasa.gov/details/PIA19952", date: "2015-07-14"),
            .init(title: "Enceladus Water Plumes (Cassini)",
                  credit: "NASA / JPL-Caltech / Space Science Institute",
                  explanation: "Cassini discovered active water-ice geysers erupting from the south pole of Saturn's moon Enceladus — a potential harbour for life.",
                  image: "https://images-assets.nasa.gov/image/PIA11133/PIA11133~large.jpg",
                  thumb: "https://images-assets.nasa.gov/image/PIA11133/PIA11133~small.jpg",
                  page: "https://images.nasa.gov/details/PIA11133", date: nil),
        ]
    )

    // 4 · Space Stations — ISS, EVAs, spacecraft portraits
    static let spaceStations = CuratedSource(
        id: "curated-stations", name: "Space Stations", subtitle: "ISS & beyond",
        symbol: "antenna.radiowaves.left.and.right", accentHex: 0xFF8A5E, typicalResolution: .uhd,
        manifestURL: URL(string: "https://professorengineergit.github.io/caelum/curated-stations.json")!,
        embedded: [
            .init(title: "ISS over a Moonlit Ocean",
                  credit: "NASA / ESA",
                  explanation: "The International Space Station orbits at 408 km altitude above a moonlit ocean, framed by the thin line of Earth's atmosphere.",
                  image: "https://images-assets.nasa.gov/image/iss065e277302/iss065e277302~large.jpg",
                  thumb: "https://images-assets.nasa.gov/image/iss065e277302/iss065e277302~small.jpg",
                  page: "https://images.nasa.gov/details/iss065e277302", date: nil),
            .init(title: "ISS Full Portrait (STS-132)",
                  credit: "NASA",
                  explanation: "The Space Shuttle Atlantis photographed the ISS at its full extent during the STS-132 mission — a rare portrait of humanity's largest structure in orbit.",
                  image: "https://images-assets.nasa.gov/image/iss023e050318/iss023e050318~large.jpg",
                  thumb: "https://images-assets.nasa.gov/image/iss023e050318/iss023e050318~small.jpg",
                  page: "https://images.nasa.gov/details/iss023e050318", date: nil),
            .init(title: "EVA at Sunrise",
                  credit: "NASA",
                  explanation: "An astronaut conducts a spacewalk during orbital sunrise, the curve of the Earth glowing golden beneath the station's truss structure.",
                  image: "https://images-assets.nasa.gov/image/iss053e164540/iss053e164540~large.jpg",
                  thumb: "https://images-assets.nasa.gov/image/iss053e164540/iss053e164540~small.jpg",
                  page: "https://images.nasa.gov/details/iss053e164540", date: nil),
            .init(title: "Orion Over the Moon",
                  credit: "NASA / Artemis I",
                  explanation: "The Orion spacecraft photographed during the Artemis I mission at its closest approach to the lunar surface, 130 km above the Moon.",
                  image: "https://images-assets.nasa.gov/image/art001e001523/art001e001523~large.jpg",
                  thumb: "https://images-assets.nasa.gov/image/art001e001523/art001e001523~small.jpg",
                  page: "https://images.nasa.gov/details/art001e001523", date: nil),
        ]
    )

    // 5 · Interstellar — deep fields, galaxy clusters, cosmic web
    static let interstellar = CuratedSource(
        id: "curated-inter", name: "Interstellar", subtitle: "Deep fields & beyond",
        symbol: "star.circle.fill", accentHex: 0x8B7CFF, typicalResolution: .uhd,
        manifestURL: URL(string: "https://professorengineergit.github.io/caelum/curated-inter.json")!,
        embedded: [
            .init(title: "Stephan's Quintet (JWST)",
                  credit: "NASA, ESA, CSA, STScI",
                  explanation: "JWST's first-light image of Stephan's Quintet — four of five galaxies locked in a cosmic dance 290 million light-years away, with star-forming shock waves painted in infrared.",
                  image: "https://cdn.esawebb.org/archives/images/large/weic2208b.jpg",
                  thumb: "https://cdn.esawebb.org/archives/images/screen/weic2208b.jpg",
                  page: "https://esawebb.org/images/weic2208b/", date: nil),
            .init(title: "Hubble Ultra Deep Field",
                  credit: "NASA / ESA / Hubble",
                  explanation: "Roughly 10,000 galaxies — some only 500 million years after the Big Bang — crowd this 3.4 arc-minute patch of sky in the Hubble Ultra Deep Field.",
                  image: "https://cdn.esahubble.org/archives/images/large/heic0611b.jpg",
                  thumb: "https://cdn.esahubble.org/archives/images/screen/heic0611b.jpg",
                  page: "https://esahubble.org/images/heic0611b/", date: nil),
            .init(title: "SMACS 0723 — Webb's First Deep Field",
                  credit: "NASA, ESA, CSA, STScI",
                  explanation: "The first JWST deep field image: the galaxy cluster SMACS 0723 as it appeared 4.6 billion years ago, with thousands of galaxies lensed and stretched behind it.",
                  image: "https://cdn.esawebb.org/archives/images/large/weic2208a.jpg",
                  thumb: "https://cdn.esawebb.org/archives/images/screen/weic2208a.jpg",
                  page: "https://esawebb.org/images/weic2208a/", date: nil),
            .init(title: "Pandora's Cluster (JWST)",
                  credit: "NASA, ESA, CSA, STScI",
                  explanation: "Webb reveals Pandora's Cluster — three clusters of galaxies merging, their combined gravity acting as a lens that magnifies distant background galaxies into brilliant arcs.",
                  image: "https://cdn.esawebb.org/archives/images/large/weic2301a.jpg",
                  thumb: "https://cdn.esawebb.org/archives/images/screen/weic2301a.jpg",
                  page: "https://esawebb.org/images/weic2301a/", date: nil),
            .init(title: "Hubble Heritage — Andromeda Galaxy",
                  credit: "NASA, ESA, J. Dalcanton et al.",
                  explanation: "The Andromeda Galaxy (M31) — the Milky Way's nearest large neighbour, 2.5 million light-years away and destined to merge with our own galaxy in ~4 billion years.",
                  image: "https://cdn.esahubble.org/archives/images/large/heic1502a.jpg",
                  thumb: "https://cdn.esahubble.org/archives/images/screen/heic1502a.jpg",
                  page: "https://esahubble.org/images/heic1502a/", date: nil),
        ]
    )
}

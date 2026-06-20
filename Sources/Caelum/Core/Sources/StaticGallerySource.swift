import Foundation

/// A fixed gallery of hand-picked, resolution-verified NASA assets. Used where
/// the live search is unreliable (planetary imagery). Each asset resolves to its
/// `~orig` (maximum-resolution) file, with `ImageCache` falling back to the
/// thumbnail if needed. Rotates daily for variety while staying deterministic so
/// the prefetcher caches exactly what's shown.
struct StaticGallerySource: ImageSource {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let accentHex: UInt32
    var typicalResolution: ResolutionHint {
        if assets.contains(where: { $0.resolution == .uhd }) { return .uhd }
        if assets.contains(where: { $0.resolution == .hd }) { return .hd }
        return .sd
    }
    let assets: [Asset]

    struct Asset {
        let identifier: String
        let title: String
        let credit: String
        let explanation: String
        let date: Date?
        let pageURL: URL?
        let imageURL: URL
        let thumbURL: URL?
        let resolution: ResolutionHint

        init(title: String,
             nasaID: String,
             credit: String,
             explanation: String,
             dateString: String? = nil,
             resolution: ResolutionHint = .uhd) {
            let base = "https://images-assets.nasa.gov/image/\(nasaID)/\(nasaID)"
            self.identifier = nasaID
            self.title = title
            self.credit = credit
            self.explanation = explanation
            self.date = dateString.flatMap { CaelumDates.ymd.date(from: $0) }
            self.pageURL = URL(string: "https://images.nasa.gov/details/\(nasaID)")
            self.imageURL = URL(string: base + "~orig.jpg")!
            self.thumbURL = URL(string: base + "~medium.jpg")
            self.resolution = resolution
        }

        init(identifier: String,
             title: String,
             credit: String,
             explanation: String,
             imageURL: String,
             thumbURL: String? = nil,
             pageURL: String? = nil,
             dateString: String? = nil,
             resolution: ResolutionHint = .uhd) {
            self.identifier = identifier
            self.title = title
            self.credit = credit
            self.explanation = explanation
            self.date = dateString.flatMap { CaelumDates.ymd.date(from: $0) }
            self.pageURL = pageURL.flatMap(URL.init(string:))
            self.imageURL = URL(string: imageURL)!
            self.thumbURL = thumbURL.flatMap(URL.init(string:))
            self.resolution = resolution
        }
    }

    func fetchRecent(limit: Int) async throws -> [CosmicImage] {
        guard !assets.isEmpty else { throw SourceError.empty }
        let offset = Int(Date().timeIntervalSince1970 / 86_400) % assets.count
        let rotated = Array(assets[offset...] + assets[..<offset])
        let images = rotated.map { asset in
            CosmicImage(
                id: "\(id)-\(asset.identifier)",
                title: asset.title,
                credit: asset.credit,
                explanation: asset.explanation,
                date: asset.date,
                sourceID: id,
                pageURL: asset.pageURL,
                imageURL: asset.imageURL,
                thumbURL: asset.thumbURL,
                isVideo: false,
                resolution: asset.resolution)
        }
        return Array(images.prefix(max(limit, 1)))
    }
}

extension StaticGallerySource {
    /// Deep Space — stable 4K+ observatory classics instead of daily feed noise.
    static let deep = StaticGallerySource(
        id: "deep", name: "Deep Space", subtitle: "Nebulae & galaxies",
        symbol: "sparkle.magnifyingglass", accentHex: 0xB8C0FF,
        assets: [
            .init(identifier: "weic2205a",
                  title: "Cosmic Cliffs of Carina",
                  credit: "NASA, ESA, CSA, STScI",
                  explanation: "Webb's 14K infrared view of the star-forming edge of NGC 3324 in the Carina Nebula.",
                  imageURL: "https://cdn.esawebb.org/archives/images/large/weic2205a.jpg",
                  thumbURL: "https://cdn.esawebb.org/archives/images/screen/weic2205a.jpg",
                  pageURL: "https://esawebb.org/images/weic2205a/"),
            .init(identifier: "heic1509a",
                  title: "Pillars of Creation",
                  credit: "NASA, ESA, Hubble Heritage Team",
                  explanation: "Hubble's high-resolution visible-light portrait of the Pillars of Creation in the Eagle Nebula.",
                  imageURL: "https://cdn.esahubble.org/archives/images/large/heic1509a.jpg",
                  thumbURL: "https://cdn.esahubble.org/archives/images/screen/heic1509a.jpg",
                  pageURL: "https://esahubble.org/images/heic1509a/"),
            .init(identifier: "heic0611b",
                  title: "Hubble Ultra Deep Field",
                  credit: "NASA / ESA / Hubble",
                  explanation: "Thousands of galaxies fill one of Hubble's deepest views of the universe.",
                  imageURL: "https://cdn.esahubble.org/archives/images/large/heic0611b.jpg",
                  thumbURL: "https://cdn.esahubble.org/archives/images/screen/heic0611b.jpg",
                  pageURL: "https://esahubble.org/images/heic0611b/"),
            .init(identifier: "potm2605a",
                  title: "Galaxy Cluster Core",
                  credit: "ESA/Hubble & NASA",
                  explanation: "Hubble peers into a dense galaxy cluster packed with distant galaxies.",
                  imageURL: "https://cdn.esahubble.org/archives/images/large/potm2605a.jpg",
                  thumbURL: "https://cdn.esahubble.org/archives/images/screen/potm2605a.jpg",
                  pageURL: "https://esahubble.org/images/potm2605a/"),
            .init(identifier: "weic2609c",
                  title: "A Little Red Dot",
                  credit: "ESA/Webb, NASA & CSA",
                  explanation: "Webb looks across cosmic time toward Abell 2744 and very distant early-universe objects.",
                  imageURL: "https://cdn.esawebb.org/archives/images/large/weic2609c.jpg",
                  thumbURL: "https://cdn.esawebb.org/archives/images/screen/weic2609c.jpg",
                  pageURL: "https://esawebb.org/images/weic2609c/"),
        ])

    /// Earth from orbit — no people, no press-room photos, high pixel count.
    static let earth = StaticGallerySource(
        id: "earth", name: "Earth from Space", subtitle: "Orbit & lunar views",
        symbol: "globe.europe.africa.fill", accentHex: 0x5EF2B0,
        assets: [
            .init(title: "Moonlit Pacific from the ISS", nasaID: "iss071e456772",
                  credit: "NASA",
                  explanation: "Moon glint, airglow and stars photographed from the International Space Station above the Pacific Ocean.",
                  dateString: "2024-07-18"),
            .init(title: "Aurora from the Station", nasaID: "iss058e005282",
                  credit: "NASA",
                  explanation: "Earth's limb and aurora beneath the International Space Station's solar arrays.",
                  dateString: "2019-01-19"),
            .init(title: "Orbital Star Trails", nasaID: "iss074e0319988",
                  credit: "NASA/JAXA",
                  explanation: "A long-duration exposure from the ISS turns city lights and stars into streaks above Earth.",
                  dateString: "2026-02-19"),
            .init(title: "Earthset from Orion", nasaID: "art002e009288",
                  credit: "NASA",
                  explanation: "Earth drops behind the Moon as photographed from the Orion spacecraft.",
                  dateString: "2026-04-01"),
        ])

    /// Solar System — verified high-resolution planetary imagery.
    static let solar = StaticGallerySource(
        id: "solar", name: "Solar System", subtitle: "Planets & moons",
        symbol: "sun.max.fill", accentHex: 0xFFD166,
        assets: [
            .init(title: "Jupiter's Great Red Spot", nasaID: "PIA01384",
                  credit: "NASA/JPL",
                  explanation: "Voyager 1's high-resolution color view of Jupiter and the Great Red Spot."),
            .init(title: "The Rich Colors of Pluto", nasaID: "PIA19952",
                  credit: "NASA/JHUAPL/SwRI",
                  explanation: "New Horizons' enhanced-color portrait of Pluto from its 2015 flyby.",
                  dateString: "2015-07-14"),
            .init(title: "The Day the Earth Smiled", nasaID: "PIA17172",
                  credit: "NASA/JPL-Caltech/SSI",
                  explanation: "A 9,000-pixel Cassini mosaic of Saturn backlit by the Sun, with Earth as a faint dot."),
            .init(title: "Saturn Noodle Mosaic", nasaID: "PIA21617",
                  credit: "NASA/JPL-Caltech/SSI",
                  explanation: "Cassini's Grand Finale mosaic reveals Saturn's north polar vortex, hexagon and cloud bands."),
            .init(title: "Jupiter Marble", nasaID: "PIA22946",
                  credit: "NASA/JPL-Caltech/SwRI/MSSS",
                  explanation: "Juno's color-enhanced close pass over Jupiter's turbulent southern hemisphere.",
                  resolution: .hd),
        ])

    /// Spacecraft — orbital hardware and ships, curated away from people.
    static let stations = StaticGallerySource(
        id: "stations", name: "Spacecraft", subtitle: "Orion, ISS & satellites",
        symbol: "antenna.radiowaves.left.and.right", accentHex: 0xFF8A5E,
        assets: [
            .init(title: "CubeSats Deploy from the ISS", nasaID: "iss074e0301636",
                  credit: "NASA",
                  explanation: "A trio of CubeSats deploys into Earth orbit from the International Space Station.",
                  dateString: "2026-02-03"),
            .init(title: "CubeSat Pair in Orbit", nasaID: "iss074e0301064",
                  credit: "NASA",
                  explanation: "Two small satellites drift away from the station's Kibo laboratory module.",
                  dateString: "2026-02-03"),
            .init(title: "Orion Approaches the Moon", nasaID: "art001e000269",
                  credit: "NASA",
                  explanation: "The Orion spacecraft approaches the Moon during Artemis I's outbound powered flyby.",
                  dateString: "2022-11-21"),
            .init(title: "Orion Between Earth and Moon", nasaID: "art001e001713",
                  credit: "NASA",
                  explanation: "Orion's solar array wing cuts between Earth and Moon during Artemis I.",
                  dateString: "2022-12-02"),
            .init(title: "Orion Looks Back", nasaID: "art001e002186",
                  credit: "NASA",
                  explanation: "The Orion spacecraft looks back at the Moon late in the Artemis I mission.",
                  dateString: "2022-12-08"),
            .init(title: "ISS Aurora View", nasaID: "iss058e005282",
                  credit: "NASA",
                  explanation: "Station solar arrays frame Earth's limb and aurora from low Earth orbit.",
                  dateString: "2019-01-19"),
        ])

    /// The one Science-Fiction category: Interstellar film frames plus NASA's
    /// high-resolution "Visions of the Future" sci-fi art.
    static let interstellar = StaticGallerySource(
        id: "interstellar", name: "Sci-Fi", subtitle: "Interstellar & beyond",
        symbol: "hurricane", accentHex: 0x8B7CFF,
        assets: [
            .init(title: "Exoplanet HD 40307g", nasaID: "PIA22085",
                  credit: "NASA/JPL-Caltech",
                  explanation: "From NASA's \"Visions of the Future\" series — a retro-futurist travel poster for the super-Earth HD 40307g.",
                  resolution: .uhd),
            .init(title: "Grand Tour of the Solar System", nasaID: "PIA22086",
                  credit: "NASA/JPL-Caltech",
                  explanation: "A 5K \"Visions of the Future\" poster imagining a grand tour of the planets.",
                  resolution: .uhd),
            .init(title: "Exoplanet Travel Bureau", nasaID: "PIA22087",
                  credit: "NASA/JPL-Caltech",
                  explanation: "NASA/JPL's sci-fi-styled exoplanet travel poster art.",
                  resolution: .uhd),
            .init(identifier: "interstellar-023",
                  title: "Endurance Above Earth",
                  credit: "Interstellar (2014) / SceneStill",
                  explanation: "A wide film frame of the Endurance in orbit above Earth.",
                  imageURL: "https://www.scenestill.com/storage/film-stills/full/Interstellar_screencap_023_full.jpg",
                  pageURL: "https://www.scenestill.com/films/157336",
                  resolution: .hd),
            .init(identifier: "interstellar-027",
                  title: "Orbit Burn",
                  credit: "Interstellar (2014) / SceneStill",
                  explanation: "Earth's limb and a distant spacecraft, selected for the film's clean orbital scale.",
                  imageURL: "https://www.scenestill.com/storage/film-stills/full/Interstellar_screencap_027_full.jpg",
                  pageURL: "https://www.scenestill.com/films/157336",
                  resolution: .hd),
            .init(identifier: "interstellar-035",
                  title: "Ranger in the Dark",
                  credit: "Interstellar (2014) / SceneStill",
                  explanation: "A dark spacecraft frame with no people in view.",
                  imageURL: "https://www.scenestill.com/storage/film-stills/full/Interstellar_screencap_035_full.jpg",
                  pageURL: "https://www.scenestill.com/films/157336",
                  resolution: .hd),
            .init(identifier: "interstellar-036",
                  title: "Ranger Docking",
                  credit: "Interstellar (2014) / SceneStill",
                  explanation: "Spacecraft hardware and docking geometry in the film's low-light palette.",
                  imageURL: "https://www.scenestill.com/storage/film-stills/full/Interstellar_screencap_036_full.jpg",
                  pageURL: "https://www.scenestill.com/films/157336",
                  resolution: .hd),
            .init(identifier: "interstellar-040",
                  title: "Gargantua",
                  credit: "Interstellar (2014) / SceneStill",
                  explanation: "The film's black-hole composition, curated as the category anchor.",
                  imageURL: "https://www.scenestill.com/storage/film-stills/full/Interstellar_screencap_040_full.jpg",
                  pageURL: "https://www.scenestill.com/films/157336",
                  resolution: .hd),
            .init(identifier: "interstellar-070",
                  title: "Icy World",
                  credit: "Interstellar (2014) / SceneStill",
                  explanation: "The Endurance over a white planetary surface, with no characters in the frame.",
                  imageURL: "https://www.scenestill.com/storage/film-stills/full/Interstellar_screencap_070_full.jpg",
                  pageURL: "https://www.scenestill.com/films/157336",
                  resolution: .hd),
            .init(identifier: "interstellar-073",
                  title: "Slingshot",
                  credit: "Interstellar (2014) / SceneStill",
                  explanation: "Spacecraft silhouettes against Gargantua's bright accretion disk.",
                  imageURL: "https://www.scenestill.com/storage/film-stills/full/Interstellar_screencap_073_full.jpg",
                  pageURL: "https://www.scenestill.com/films/157336",
                  resolution: .hd),
        ])
}

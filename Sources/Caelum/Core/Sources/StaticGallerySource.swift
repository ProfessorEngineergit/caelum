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
                  explanation: "Webb's infrared view of the star-forming edge of NGC 3324 in the Carina Nebula.",
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
            .init(identifier: "weic2609c",
                  title: "A Little Red Dot",
                  credit: "ESA/Webb, NASA & CSA",
                  explanation: "Webb looks across cosmic time toward Abell 2744 and very distant early-universe objects.",
                  imageURL: "https://cdn.esawebb.org/archives/images/large/weic2609c.jpg",
                  thumbURL: "https://cdn.esawebb.org/archives/images/screen/weic2609c.jpg",
                  pageURL: "https://esawebb.org/images/weic2609c/"),
            .init(identifier: "weic2212a",
                  title: "Tarantula Nebula",
                  credit: "NASA, ESA, CSA, STScI",
                  explanation: "Webb's near-infrared view of star-forming region 30 Doradus.",
                  imageURL: "https://cdn.esawebb.org/archives/images/large/weic2212a.jpg",
                  thumbURL: "https://cdn.esawebb.org/archives/images/screen/weic2212a.jpg",
                  pageURL: "https://esawebb.org/images/weic2212a/"),
            .init(identifier: "weic2303a",
                  title: "Rho Ophiuchi Cloud Complex",
                  credit: "NASA, ESA, CSA, STScI",
                  explanation: "Webb's multicolored view of a nearby star-forming region with dust and nebulosity.",
                  imageURL: "https://cdn.esawebb.org/archives/images/large/weic2303a.jpg",
                  thumbURL: "https://cdn.esawebb.org/archives/images/screen/weic2303a.jpg",
                  pageURL: "https://esawebb.org/images/weic2303a/"),
            .init(identifier: "heic0601a",
                  title: "Orion Nebula",
                  credit: "NASA, ESA, Hubble Heritage Team",
                  explanation: "Hubble's expansive mosaic of the Orion Nebula reveals stellar nursery details.",
                  imageURL: "https://cdn.esahubble.org/archives/images/large/heic0601a.jpg",
                  thumbURL: "https://cdn.esahubble.org/archives/images/screen/heic0601a.jpg",
                  pageURL: "https://esahubble.org/images/heic0601a/"),
            .init(identifier: "heic0506a",
                  title: "Whirlpool Galaxy",
                  credit: "NASA, ESA, Hubble Heritage Team",
                  explanation: "Hubble's stunning face-on spiral galaxy with sharp dust lanes and golden star-forming regions.",
                  imageURL: "https://cdn.esahubble.org/archives/images/large/heic0506a.jpg",
                  thumbURL: "https://cdn.esahubble.org/archives/images/screen/heic0506a.jpg",
                  pageURL: "https://esahubble.org/images/heic0506a/"),
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
            .init(title: "Blue Marble 2012", nasaID: "PIA18033",
                  credit: "NASA",
                  explanation: "A detailed full-disk composite of Earth showing oceans, continents, and atmosphere.",
                  dateString: "2012-06-01"),
            .init(title: "Black Marble", nasaID: "GSFC_20171208_Archive_e001591",
                  credit: "NASA/NOAA",
                  explanation: "A global night-time composite showing city lights, auroras, and natural luminescence.",
                  dateString: "2017-12-08"),
            .init(title: "Artemis Era Earthrise", nasaID: "art002e009280b",
                  credit: "NASA",
                  explanation: "A crescent Earth framed through the window of the Orion spacecraft.",
                  dateString: "2026-04-01"),
            .init(title: "Aurora and City Lights", nasaID: "iss029e012564",
                  credit: "NASA",
                  explanation: "Aurora borealis and night-side city lights illuminate Earth from the ISS vantage point.",
                  dateString: "2012-09-01"),
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
            .init(title: "95 Minutes Over Jupiter", nasaID: "PIA21967",
                  credit: "NASA/JPL-Caltech/SwRI/MSSS",
                  explanation: "A dramatic 16K-wide JunoCam sequence captures Jupiter's cloud patterns and colors.",
                  dateString: "2018-06-01"),
            .init(title: "Juno Captures Brown Barge", nasaID: "PIA22939",
                  credit: "NASA/JPL-Caltech/SwRI/MSSS",
                  explanation: "A 6K Juno observation of a prominent brown feature in Jupiter's atmosphere.",
                  dateString: "2019-07-01"),
            .init(title: "Turbulence in Jupiter's Atmosphere", nasaID: "PIA26595",
                  credit: "NASA/JPL-Caltech/SwRI/MSSS",
                  explanation: "A recent 6.8K Juno image of dramatic cloud formations in Jupiter's upper atmosphere.",
                  dateString: "2023-03-01"),
            .init(title: "Pluto's Twilight Zone", nasaID: "PIA20727",
                  credit: "NASA/JHUAPL/SwRI",
                  explanation: "New Horizons captures Pluto's crescent with atmospheric haze and subtle color contrasts.",
                  dateString: "2015-07-14"),
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
            .init(title: "Dragon CRS-9 Approaches the ISS", nasaID: "iss048e042025",
                  credit: "NASA",
                  explanation: "The SpaceX Dragon cargo spacecraft approaches the International Space Station for docking.",
                  dateString: "2016-07-03"),
            .init(title: "Moonlit ISS Solar Arrays", nasaID: "iss073e0850593",
                  credit: "NASA",
                  explanation: "ISS hardware glows with an unusual violet hue under moonlight in Earth orbit.",
                  dateString: "2024-01-15"),
            .init(title: "Voyager Enters Interstellar Space", nasaID: "PIA17462",
                  credit: "NASA/JPL",
                  explanation: "An 8K NASA/JPL concept depicting the historic Voyager probe leaving our solar system.",
                  dateString: "2012-09-01"),
            .init(title: "Perseverance Rover on Mars", nasaID: "PIA21635",
                  credit: "NASA/JPL-Caltech",
                  explanation: "A photorealistic concept rendering of the Mars 2020 Perseverance rover at work on the Martian surface.",
                  dateString: "2017-07-01"),
        ])

    /// The one Science-Fiction category: verified NASA/JPL concept art and
    /// high-resolution exoplanet travel posters, all 4K+ and sharp.
    static let interstellar = StaticGallerySource(
        id: "interstellar", name: "Sci-Fi", subtitle: "Interstellar & beyond",
        symbol: "hurricane", accentHex: 0x8B7CFF,
        assets: [
            .init(title: "TRAPPIST-1 Seven Worlds", nasaID: "PIA21422",
                  credit: "NASA/JPL-Caltech",
                  explanation: "Seven Earth-size worlds orbit the ultracool dwarf star TRAPPIST-1 in this artist's concept.",
                  dateString: "2017-02-22"),
            .init(title: "Black Hole Accretion Disk", nasaID: "PIA16695",
                  credit: "NASA/JPL-Caltech",
                  explanation: "A supermassive black hole draws in stellar material through a glowing accretion disk, ejecting a powerful relativistic jet.",
                  dateString: "2013-02-26"),
            .init(title: "Ocean World of TRAPPIST-1e", nasaID: "PIA23002",
                  credit: "NASA/JPL-Caltech",
                  explanation: "A NASA/JPL artist's concept of a temperate ocean world in the TRAPPIST-1 system with sibling planets crossing the sky.",
                  dateString: "2018-10-01"),
            .init(title: "Gas Giant at a Red Dwarf", nasaID: "PIA23004",
                  credit: "NASA/JPL-Caltech",
                  explanation: "A dramatic NASA concept of a large pink-hued gas giant orbiting close to a glowing red dwarf star.",
                  dateString: "2018-10-01"),
            .init(title: "Exoplanet HD 40307g Concept", nasaID: "PIA22085",
                  credit: "NASA/JPL-Caltech",
                  explanation: "A NASA/JPL Visions of the Future concept of the super-Earth HD 40307g under the glow of its host star.",
                  dateString: "2017-11-01"),
            .init(title: "Where the Sun Sets Twice", nasaID: "PIA14724",
                  credit: "NASA/JPL-Caltech",
                  explanation: "An 8K NASA/JPL circumbinary-planet concept with a cinematic dual-sunset horizon.",
                  dateString: "2012-04-01"),
            .init(title: "Surface of TRAPPIST-1f", nasaID: "PIA21423",
                  credit: "NASA/JPL-Caltech",
                  explanation: "A 4.5K NASA/JPL exoplanet surface concept with visible neighboring planets in the sky.",
                  dateString: "2017-06-01"),
            .init(title: "Hot, Rocky World", nasaID: "PIA19833",
                  credit: "NASA/JPL-Caltech",
                  explanation: "A 4.8K NASA/JPL concept of a molten rocky exoplanet bathed in stellar radiation.",
                  dateString: "2015-10-01"),
        ])
}

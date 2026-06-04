import Foundation

/// The catalogue of all image sources, in display order. APOD is always first.
/// Adding a new source is as simple as appending it here.
enum SourceRegistry {
    static let all: [ImageSource] = [
        // Observatories (all 4K/UHD from dedicated CDNs)
        APODSource(),                    // ⭐ the star
        DjangoplicitySource.hubble,      // ESA/Hubble
        DjangoplicitySource.webb,        // James Webb
        DjangoplicitySource.eso,         // ESO

        // NASA live feeds
        EPICSource(),                    // Earth from DSCOVR
        NASAImageLibrarySource(),        // NASA Image & Video Library
        NASAIOTDSource(),                // NASA Image of the Day

        // Wikimedia editorial pick
        WikimediaSource(),               // Wikimedia Picture of the Day

        // Hand-curated 4K/UHD galleries
        CuratedSource.deepSpace,         // Nebulae, galaxies
        CuratedSource.earthFromSpace,    // Astronaut photography
        CuratedSource.solarSystem,       // Planets & moons
        CuratedSource.spaceStations,     // ISS & spacecraft
        CuratedSource.interstellar,      // Deep fields
    ]

    static func source(id: String) -> ImageSource {
        all.first { $0.id == id } ?? all[0]
    }

    /// The user's currently selected source.
    static var active: ImageSource {
        source(id: Preferences.shared.activeSourceID)
    }
}

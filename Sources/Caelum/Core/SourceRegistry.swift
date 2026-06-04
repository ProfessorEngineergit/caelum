import Foundation

/// The catalogue of all image sources, in display order. APOD is always first.
/// Every source here is verified to return a usable high-resolution image.
enum SourceRegistry {
    static let all: [ImageSource] = [
        // Observatories (4K from dedicated CDNs)
        APODSource(),                    // ⭐ the star
        DjangoplicitySource.hubble,      // ESA/Hubble
        DjangoplicitySource.webb,        // James Webb
        DjangoplicitySource.eso,         // ESO

        // NASA live feeds
        EPICSource(),                    // Earth from DSCOVR
        NASAIOTDSource(),                // NASA Image of the Day

        // Themed NASA-library collections (4K ~orig assets)
        NASASearchSource.earth,          // Earth from Space
        NASASearchSource.solar,          // Solar System
        NASASearchSource.stations,       // Space Stations
        NASASearchSource.interstellar,   // Interstellar (black holes & wormholes)
    ]

    static func source(id: String) -> ImageSource {
        all.first { $0.id == id } ?? all[0]
    }

    /// The user's currently selected source.
    static var active: ImageSource {
        source(id: Preferences.shared.activeSourceID)
    }
}

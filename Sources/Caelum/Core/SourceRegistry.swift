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

        // Curated collections (pixel-verified, no noisy search results)
        StaticGallerySource.deep,        // Deep Space (stable 4K+ observatory classics)
        StaticGallerySource.earth,       // Earth from Space (orbit & lunar views)
        StaticGallerySource.solar,       // Solar System (verified planetary imagery)
        StaticGallerySource.stations,    // Spacecraft (Orion, ISS & satellites)
        StaticGallerySource.interstellar,// Interstellar (ships, planets, black holes)
    ]

    static func source(id: String) -> ImageSource {
        all.first { $0.id == id } ?? all[0]
    }

    /// The user's currently selected source.
    static var active: ImageSource {
        source(id: Preferences.shared.activeSourceID)
    }
}

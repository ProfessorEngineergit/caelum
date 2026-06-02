import Foundation

/// The catalogue of all image sources, in display order. APOD is always first —
/// it's the star. Adding a new source is as simple as appending it here.
enum SourceRegistry {
    static let all: [ImageSource] = [
        APODSource(),                 // ⭐ the star
        DjangoplicitySource.hubble,   // ESA/Hubble
        DjangoplicitySource.webb,     // ESA/Webb (JWST)
        DjangoplicitySource.eso,      // ESO
        EPICSource(),                 // NASA EPIC (live Earth)
        NASAImageLibrarySource(),     // NASA Image & Video Library
        BingSource(),                 // Bing Photo of the Day
        WikimediaSource(),            // Wikimedia Picture of the Day
        NASAIOTDSource(),             // NASA Image of the Day
        CuratedSource(),              // Caelum Curated
    ]

    static func source(id: String) -> ImageSource {
        all.first { $0.id == id } ?? all[0]
    }

    /// The user's currently selected source.
    static var active: ImageSource {
        source(id: Preferences.shared.activeSourceID)
    }
}

import XCTest
@testable import Caelum

final class CaelumTests: XCTestCase {
    func testBrandGlyphRenders() {
        let image = BrandGlyph.statusImage()
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size.width, 18, accuracy: 0.001)
    }
}

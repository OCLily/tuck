import Foundation
import ImageIO
import Testing

// The one rule about this asset that neither a build nor a human eye catches: an app icon carrying
// an alpha channel is rejected on upload, and ImageRenderer hands one back by default —
// tools/render-app-icon.swift flattens it out again. This pins that the flattening happened.
//
// It reads the checked-in PNG through #filePath rather than the built bundle on purpose: actool
// re-encodes the icon into flat per-size files (AppIcon60x60@2x.png), so the bundle can only show
// what actool made of it, never what was committed — and it is the committed file that is uploaded.
struct AppIconAssetTests {
    @Test func theAppIconIsSquareAtFullSizeAndCarriesNoTransparency() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let icon = repository
            .appendingPathComponent("Tuck/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

        let source = try #require(CGImageSourceCreateWithURL(icon as CFURL, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )

        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 1024)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 1024)
        #expect(properties[kCGImagePropertyHasAlpha] as? Bool != true)
    }
}

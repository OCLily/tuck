import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// Renders AppIconComposition once, on a Mac, into the app icon asset. Same shape as
// tools/render-shield-mascot.swift with one addition: the alpha channel is dropped. ImageRenderer
// always hands back a CGImage with alpha, and an app icon that carries one is rejected — even when
// every pixel in it is opaque, which here they are.
@main
struct RenderAppIcon {
    @MainActor
    static func main() {
        guard let path = CommandLine.arguments.dropFirst().first else {
            FileHandle.standardError.write(Data("usage: render-app-icon <output.png>\n".utf8))
            exit(2)
        }

        let renderer = ImageRenderer(content: AppIconComposition())
        renderer.scale = AppIconComposition.scale
        renderer.isOpaque = true

        guard let rendered = renderer.cgImage else {
            FileHandle.standardError.write(Data("ImageRenderer produced no image\n".utf8))
            exit(1)
        }

        guard let image = flattened(rendered) else {
            FileHandle.standardError.write(Data("cannot drop the alpha channel\n".utf8))
            exit(1)
        }

        let url = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            FileHandle.standardError.write(Data("cannot write \(path)\n".utf8))
            exit(1)
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            FileHandle.standardError.write(Data("cannot finalize \(path)\n".utf8))
            exit(1)
        }

        print("\(image.width)x\(image.height) alpha=\(image.alphaInfo.rawValue) → \(path)")
    }

    private static func flattened(_ image: CGImage) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }
}

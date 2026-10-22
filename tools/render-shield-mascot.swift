import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// Renders ShieldMascotIcon once, on a Mac, into the imageset the shield extension loads at runtime.
// The extension must not do this itself: every ImageRenderer member is MainActor-isolated, and the
// shield-configuration service calls the data source on a thread this XPC process neither owns nor
// can inspect — the hop to main that would be needed there can deadlock against whatever is holding
// that thread. A flat PNG has no such requirement.
@main
struct RenderShieldMascot {
    @MainActor
    static func main() {
        guard let path = CommandLine.arguments.dropFirst().first else {
            FileHandle.standardError.write(Data("usage: render-shield-mascot <output.png>\n".utf8))
            exit(2)
        }

        let renderer = ImageRenderer(content: ShieldMascotIcon())
        renderer.scale = 3

        guard let image = renderer.cgImage else {
            FileHandle.standardError.write(Data("ImageRenderer produced no image\n".utf8))
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

        print("\(image.width)x\(image.height) → \(path)")
    }
}

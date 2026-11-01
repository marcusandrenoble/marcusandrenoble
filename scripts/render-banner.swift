import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

// Rebuild the profile's selected Helvetica animation on macOS.
// Run through scripts/render-banner.sh to export both GIF and MP4.
guard CommandLine.arguments.count == 2 else {
    fputs("Usage: render-banner <output-directory>\n", stderr)
    exit(1)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let frames = output.appendingPathComponent("frames")
try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)

let name = "marcus andre noble"
let width = 2400, height = 300, frameCount = 150
let colourSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
let background = [13.0, 17.0, 23.0] // GitHub Dark default: #0d1117.
let base = [175.0, 181.0, 191.0], peak = [250.0, 251.0, 253.0]

func typography(scale: CGFloat) -> CTLine {
    let font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 204 * scale, nil)
    precondition(CTFontCopyPostScriptName(font) as String == "HelveticaNeue-Medium")
    return CTLineCreateWithAttributedString(NSAttributedString(string: name, attributes: [
        .font: font, .foregroundColor: CGColor(gray: 1, alpha: 1), .kern: -1.5 * scale
    ]))
}

let naturalBounds = CTLineGetBoundsWithOptions(typography(scale: 1), [.useGlyphPathBounds])
let line = typography(scale: 1720 / naturalBounds.width)
let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
let mask = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                     bytesPerRow: width * 4, space: colourSpace,
                     bitmapInfo: bitmapInfo.rawValue)!
mask.setShouldAntialias(true)
mask.setAllowsFontSmoothing(false)
mask.textPosition = CGPoint(x: (CGFloat(width) - bounds.width) / 2 - bounds.minX,
                           y: (CGFloat(height) - bounds.height) / 2 - bounds.minY)
CTLineDraw(line, mask)
let coverage = mask.data!.assumingMemoryBound(to: UInt8.self)

func save(_ bytes: [UInt8], to url: URL) {
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    let image = CGImage(width: width, height: height, bitsPerComponent: 8,
                       bitsPerPixel: 32, bytesPerRow: width * 4, space: colourSpace,
                       bitmapInfo: bitmapInfo, provider: provider, decode: nil,
                       shouldInterpolate: true, intent: .defaultIntent)!
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination), "Could not save \(url.path)")
}

// At 25 fps, 150 frames form one six-second loop. The periodic light field
// agrees at both endpoints. Save the extra endpoint only for verification;
// exclude it from the animation so there is no duplicated-frame pause.
for index in 0...frameCount {
    autoreleasepool {
        let period = Double(width) * 1.36
        let centre = Double(index) / Double(frameCount) * period - Double(width) * 0.18
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                let alpha = Double(coverage[i + 3]) / 255
                var light = 0.0
                if alpha > 0 {
                    let d = Double(x) + 0.27 * (Double(y) - Double(height) / 2) - centre
                    let distance = d - period * (d / period).rounded()
                    light = exp(-0.5 * pow(distance / 190, 2))
                }
                for channel in 0..<3 {
                    let ink = base[channel] + (peak[channel] - base[channel]) * light
                    pixels[i + channel] = UInt8((background[channel] * (1 - alpha) + ink * alpha).rounded())
                }
            }
        }
        let destination = index == frameCount
            ? output.appendingPathComponent("endpoint.png")
            : frames.appendingPathComponent(String(format: "frame-%04d.png", index))
        save(pixels, to: destination)
    }
}
print("Rendered 150 frames and a verification endpoint")

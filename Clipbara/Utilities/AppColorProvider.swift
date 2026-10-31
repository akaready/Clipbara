import AppKit
import SwiftUI

/// The colour of a source app's icon, used for the Colorful card header.
@MainActor
enum AppColorProvider {
    /// Raw (unadjusted) representative colour per bundle id.
    private static var cache: [String: NSColor] = [:]
    private static let sampleSize = 16
    /// Paste's headers are vivid with white text (yellow Notes included), so only the
    /// lightest colours get darkened. That is looser than a strict 3:1 contrast.
    private static let maxLuminance = 0.5

    static func headerColor(for bundleId: String?, colorScheme: ColorScheme) -> Color {
        guard let bundleId else { return Color(white: colorScheme == .dark ? 0.3 : 0.38) }
        let base: NSColor
        if let cached = cache[bundleId] {
            base = cached
        } else {
            base = representativeColor(of: AppIconProvider.icon(for: bundleId, size: 32))
            cache[bundleId] = base
        }
        return Color(nsColor: readable(base, muted: colorScheme == .dark))
    }

    /// Average of the icon's dominant hue (saturation-weighted, so white or black
    /// icon backgrounds don't wash it out), not of all hues, which turns a
    /// multicolour icon to mud. Grey if there is none.
    private static func representativeColor(of image: NSImage) -> NSColor {
        let size = sampleSize
        let grey = NSColor(white: 0.38, alpha: 1)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return grey }

        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: size, height: size,
                bitsPerComponent: 8, bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
            return true
        }
        guard drawn else { return grey }

        let buckets = 12
        var sums = [[Double]](repeating: [0, 0, 0, 0], count: buckets)
        for i in 0..<(size * size) {
            let a = Double(pixels[i * 4 + 3]) / 255
            guard a > 0.5 else { continue }
            let pr = Double(pixels[i * 4]) / 255 / a
            let pg = Double(pixels[i * 4 + 1]) / 255 / a
            let pb = Double(pixels[i * 4 + 2]) / 255 / a
            let top = max(pr, pg, pb)
            let saturation = top > 0 ? (top - min(pr, pg, pb)) / top : 0
            guard saturation > 0.25, top > 0.2 else { continue }
            let w = saturation * saturation
            let hue = NSColor(srgbRed: pr, green: pg, blue: pb, alpha: 1).hueComponent
            let k = min(Int(hue * Double(buckets)), buckets - 1)
            sums[k][0] += pr * w; sums[k][1] += pg * w; sums[k][2] += pb * w; sums[k][3] += w
        }
        guard let best = sums.max(by: { $0[3] < $1[3] }), best[3] > 0 else { return grey }
        return NSColor(srgbRed: best[0] / best[3], green: best[1] / best[3], blue: best[2] / best[3], alpha: 1)
    }

    /// Darkens (and, in dark mode, mutes) until white text reaches 3:1.
    private static func readable(_ color: NSColor, muted: Bool) -> NSColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        (color.usingColorSpace(.sRGB) ?? color).getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        s = max(s, 0.75)
        b = max(b, 0.9)
        if muted { s *= 0.85; b *= 0.85 }
        var result = NSColor(hue: h, saturation: s, brightness: b, alpha: 1)
        while luminance(result) > maxLuminance, b > 0.05 {
            b *= 0.96
            result = NSColor(hue: h, saturation: s, brightness: b, alpha: 1)
        }
        return result
    }

    private static func luminance(_ color: NSColor) -> Double {
        let c = color.usingColorSpace(.sRGB) ?? color
        func linear(_ v: CGFloat) -> Double {
            let v = Double(v)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(c.redComponent) + 0.7152 * linear(c.greenComponent) + 0.0722 * linear(c.blueComponent)
    }
}

import AppKit
import SwiftUI

/// The colour of a source app's icon, used for the Colorful card header.
@MainActor
enum AppColorProvider {
    /// Raw (unadjusted) representative colour per bundle id.
    private static var cache: [String: NSColor] = [:]
    private static let sampleSize = 16
    /// White text needs a background no lighter than this luminance for 4.5:1.
    private static let maxLuminance = 1.05 / 4.5 - 0.05

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

    /// Saturation-weighted average of the icon's opaque pixels, so white or
    /// black icon backgrounds don't wash the hue out. Grey if there is none.
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

        var r = 0.0, g = 0.0, b = 0.0, weight = 0.0
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
            r += pr * w; g += pg * w; b += pb * w; weight += w
        }
        guard weight > 0 else { return grey }
        return NSColor(srgbRed: r / weight, green: g / weight, blue: b / weight, alpha: 1)
    }

    /// Darkens (and, in dark mode, mutes) until white text reaches 4.5:1.
    private static func readable(_ color: NSColor, muted: Bool) -> NSColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        (color.usingColorSpace(.sRGB) ?? color).getHue(&h, saturation: &s, brightness: &b, alpha: nil)
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

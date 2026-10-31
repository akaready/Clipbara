import SwiftUI
import AppKit

struct ImageCardContent: View {
    let item: ClipboardItem
    @State private var cachedImage: NSImage?
    @AppStorage(PanelController.fitImageCardsDefaultsKey) private var fitImageCards: Bool = false
    /// Paste's Colorful cards overlay the pixel size at the bottom.
    var showsDimensions = false

    private func pixelSize(of image: NSImage) -> String? {
        guard let rep = image.representations.first, rep.pixelsWide > 0 else { return nil }
        return "\(rep.pixelsWide) \u{00D7} \(rep.pixelsHigh)"
    }

    var body: some View {
        Group {
            if let image = cachedImage {
                ZStack {
                    if !fitImageCards {
                        CheckerboardPattern()
                    }
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: fitImageCards ? .fill : .fit)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    if showsDimensions, let size = pixelSize(of: image) {
                        Text(size)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.4), radius: 1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.3), in: Capsule())
                            .padding(.bottom, 8)
                    }
                }
                .clipped()
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: item.id) {
            cachedImage = ThumbnailImageCache.image(for: item)
        }
    }
}

// MARK: - Checkerboard Pattern

private struct CheckerboardPattern: View {
    private let cellSize = DesignTokens.Checkerboard.cellSize

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / cellSize))
            let rows = Int(ceil(size.height / cellSize))

            // Fill with light color first
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(DesignTokens.Checkerboard.lightColor)
            )

            // Draw dark cells
            for row in 0..<rows {
                for col in 0..<cols where (row + col).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(col) * cellSize,
                        y: CGFloat(row) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    context.fill(Path(rect), with: .color(DesignTokens.Checkerboard.darkColor))
                }
            }
        }
    }
}

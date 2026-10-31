import SwiftUI
import AppKit

struct LinkCardContent: View {
    let item: ClipboardItem
    var searchText: String = ""
    var scale: CGFloat = 1
    /// Paste layout: preview on top, bold title and grey address below.
    var colorful = false
    @Environment(\.colorScheme) private var colorScheme

    private var urlString: String {
        item.textContent ?? ""
    }

    private var domain: String {
        guard let url = URL(string: urlString) else { return urlString }
        return url.host ?? urlString
    }

    private var preview: some View {
        Group {
            if let image = item.thumbnailData.flatMap(NSImage.init(data:)) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 30 * scale, weight: .light))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    var body: some View {
        if colorful {
            VStack(alignment: .leading, spacing: 0) {
                preview
                VStack(alignment: .leading, spacing: 2) {
                    Text(TextHighlighter.highlight(domain, query: searchText))
                        .font(.system(size: 11 * scale, weight: .semibold))
                        .foregroundStyle(DesignTokens.Body.textColor(for: colorScheme))
                    Text(TextHighlighter.highlight(urlString, query: searchText))
                        .font(.system(size: 10 * scale))
                        .foregroundStyle(DesignTokens.Colorful.footerTextColor(for: colorScheme))
                }
                .lineLimit(1)
                .padding(.leading, DesignTokens.Colorful.contentInset)
                .padding(.trailing, 28) // clear of the card's menu button
                .padding(.vertical, 8)
            }
        } else {
            classicBody
        }
    }

    private var classicBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 14 * scale, weight: .medium))
                    .foregroundStyle(.blue.opacity(0.8))

                Text(TextHighlighter.highlight(domain, query: searchText))
                    .font(.system(size: 12 * scale, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(DesignTokens.Body.textColor(for: colorScheme).opacity(0.95))
            }

            Text(TextHighlighter.highlight(urlString, query: searchText))
                .font(.system(size: 10 * scale))
                .lineLimit(scale > 1 ? nil : 3)
                .foregroundStyle(DesignTokens.Body.textColor(for: colorScheme).opacity(0.58))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

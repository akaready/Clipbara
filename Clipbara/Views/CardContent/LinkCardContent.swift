import SwiftUI

struct LinkCardContent: View {
    let item: ClipboardItem
    var searchText: String = ""
    var scale: CGFloat = 1
    @Environment(\.colorScheme) private var colorScheme

    private var urlString: String {
        item.textContent ?? ""
    }

    private var domain: String {
        guard let url = URL(string: urlString) else { return urlString }
        return url.host ?? urlString
    }

    var body: some View {
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

import SwiftUI
import AppKit

struct FileCardContent: View {
    let item: ClipboardItem
    var searchText: String = ""
    var scale: CGFloat = 1
    @Environment(\.colorScheme) private var colorScheme
    @State private var cachedFileIcon: NSImage?

    private var fileName: String {
        item.textContent ?? "File"
    }

    private func loadFileIcon() -> NSImage {
        if let urlString = String(data: item.rawData, encoding: .utf8),
           let url = URL(string: urlString) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: cachedFileIcon ?? NSWorkspace.shared.icon(for: .data))
                .resizable()
                .frame(width: 32 * scale, height: 32 * scale)

            Text(TextHighlighter.highlight(fileName, query: searchText))
                .font(.system(size: 11 * scale))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(DesignTokens.Body.textColor(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: item.id) {
            cachedFileIcon = loadFileIcon()
        }
    }
}

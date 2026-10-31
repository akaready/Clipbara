import SwiftUI

struct TextCardContent: View {
    let item: ClipboardItem
    var searchText: String = ""
    var scale: CGFloat = 1
    @Environment(\.colorScheme) private var colorScheme
    @State private var isCode: Bool = false

    private var previewText: String {
        guard let text = item.textContent else { return "..." }
        let maxCharacters = 900
        if text.count <= maxCharacters {
            return text
        }
        return String(text.prefix(maxCharacters)) + "..."
    }

    var body: some View {
        Group {
            if searchText.isEmpty {
                Text(previewText)
            } else {
                Text(TextHighlighter.highlight(previewText, query: searchText))
            }
        }
        .font(.system(size: DesignTokens.Body.fontSize * scale, design: isCode ? .monospaced : .default))
        .lineSpacing(DesignTokens.Body.lineSpacing * scale)
        .lineLimit(scale > 1 ? nil : DesignTokens.Body.maxLines)
        .multilineTextAlignment(.leading)
        .foregroundStyle(DesignTokens.Body.textColor(for: colorScheme))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: item.id) {
            guard let text = item.textContent else { return }
            let sample = text.prefix(900)
            let codeIndicators = ["func ", "var ", "let ", "class ", "import ", "def ", "return ", "{", "}", "=>", "->", "();", "//", "/*"]
            isCode = codeIndicators.contains { sample.contains($0) }
        }
    }
}

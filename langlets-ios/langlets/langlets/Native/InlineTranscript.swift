import SwiftUI

struct NativeInlinePhrase: View {
    let phrase: NativePhrase
    let time: Double?
    let selectedId: Int?
    let select: (NativeToken) -> Void
    var body: some View {
        Text(attributed).font(.title3).tint(.primary)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "langlets-word", let id = url.host.flatMap { Int($0) }, let token = phrase.tokens.first(where: { $0.id == id }) else { return .discarded }
                select(token)
                return .handled
            })
    }
    var attributed: AttributedString {
        let scalars = Array(phrase.text.unicodeScalars)
        var result = AttributedString(); var cursor = 0
        for token in phrase.tokens.sorted(by: { ($0.startIndex ?? 0) < ($1.startIndex ?? 0) }) {
            guard let first = token.startIndex, let last = token.endIndex, first >= cursor, last >= first, last < scalars.count else { continue }
            if cursor < first { result += AttributedString(String(String.UnicodeScalarView(scalars[cursor..<first]))) }
            var span = AttributedString(String(String.UnicodeScalarView(scalars[first...last])))
            span.link = URL(string: "langlets-word://\(token.id)")
            if selectedId == token.id { span.foregroundColor = .mint }
            else if let time, (token.start ?? .infinity) <= time, (token.end ?? -.infinity) > time { span.backgroundColor = .mint.opacity(0.3) }
            result += span; cursor = last + 1
        }
        if cursor < scalars.count { result += AttributedString(String(String.UnicodeScalarView(scalars[cursor...]))) }
        return result
    }
}

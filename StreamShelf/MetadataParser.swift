import Foundation

enum MetadataParser {
    static func seasonEpisode(_ text: String) -> (Int?, Int?) {
        let patterns = [
            #"(?i)\bS(?:eason)?\s*0?(\d{1,2})\s*E(?:p(?:isode)?)?\s*0?(\d{1,3})\b"#,
            #"(?i)\b(\d{1,2})\s*[xх]\s*(\d{1,3})\b"#,
            #"(?i)\bсезон\s*0?(\d{1,2}).{0,20}сер(?:ия)?\s*0?(\d{1,3})\b"#
        ]
        for p in patterns {
            guard let r = try? NSRegularExpression(pattern: p),
                  let m = r.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
                  let sr = Range(m.range(at: 1), in: text),
                  let er = Range(m.range(at: 2), in: text),
                  let s = Int(text[sr]), let e = Int(text[er]) else { continue }
            return (s, e)
        }
        return (nil, nil)
    }

    static func cleanTitle(_ title: String) -> String {
        title.replacingOccurrences(of: #"(?i)\s*[|—-]\s*(HD.?Repka|Seasonvar).*$"#,
                                   with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

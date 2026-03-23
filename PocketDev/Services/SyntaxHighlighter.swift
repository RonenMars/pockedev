import Foundation
import UIKit

// MARK: - SyntaxHighlighter
// Pure function: text + file extension → NSMutableAttributedString with syntax colors.
// Regex patterns are compiled once (static). Files above maxHighlightBytes skip highlighting
// to prevent stutter on large generated files (e.g. package-lock.json).

enum SyntaxHighlighter {

    private static let maxHighlightBytes = 20_000

    // MARK: - Public API

    static func highlight(text: String, fileExtension: String) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor(red: 0.90, green: 0.93, blue: 0.95, alpha: 1) // textPrimary
            ]
        )
        guard text.utf16.count <= maxHighlightBytes else { return result }
        let lang = language(for: fileExtension)
        guard lang != .plain else { return result }
        apply(passes: passes(for: lang), to: result)
        return result
    }

    // MARK: - Language

    private enum Language { case swift, javascript, python, json, markdown, plain }

    private static func language(for ext: String) -> Language {
        switch ext.lowercased() {
        case "swift":                       return .swift
        case "js", "ts", "jsx", "tsx":      return .javascript
        case "py":                          return .python
        case "json":                        return .json
        case "md", "markdown":              return .markdown
        default:                            return .plain
        }
    }

    // MARK: - Token colors

    private enum C {
        static let keyword  = UIColor(red: 1.00, green: 0.48, blue: 0.45, alpha: 1) // #FF7B72
        static let string   = UIColor(red: 0.65, green: 0.84, blue: 1.00, alpha: 1) // #A5D6FF
        static let comment  = UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1) // #8C949E
        static let number   = UIColor(red: 0.47, green: 0.75, blue: 1.00, alpha: 1) // #79C0FF
        static let type_    = UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 1) // #F5A623
    }

    // MARK: - Passes (low priority → high priority; last writer wins per range)

    typealias Pass = (regex: NSRegularExpression, color: UIColor)

    private static func passes(for lang: Language) -> [Pass] {
        switch lang {
        case .swift:      return swiftPasses
        case .javascript: return jsPasses
        case .python:     return pythonPasses
        case .json:       return jsonPasses
        case .markdown:   return markdownPasses
        case .plain:      return []
        }
    }

    // MARK: - Swift

    private static let swiftPasses: [Pass] = compile([
        (#"\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#,   C.number),
        (#"\b[A-Z][a-zA-Z0-9_]*\b"#,               C.type_),
        (#"\b(?:import|class|struct|enum|protocol|extension|func|var|let|if|else|guard|switch|case|default|return|for|in|while|do|try|catch|throw|throws|rethrows|async|await|actor|nonisolated|init|deinit|override|final|private|public|internal|fileprivate|open|static|lazy|mutating|nonmutating|typealias|associatedtype|where|true|false|nil|self|super|as|is|some|any)\b"#, C.keyword),
        (#""(?:[^"\\]|\\.)*""#,                     C.string),
        (#"//[^\n]*"#,                              C.comment),
        (#"/\*[\s\S]*?\*/"#,                        C.comment),
    ])

    // MARK: - JavaScript / TypeScript

    private static let jsPasses: [Pass] = compile([
        (#"\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#,   C.number),
        (#"\b[A-Z][a-zA-Z0-9_]*\b"#,               C.type_),
        (#"\b(?:import|export|from|default|class|extends|function|const|let|var|if|else|switch|case|break|return|for|of|in|while|do|try|catch|finally|throw|new|delete|typeof|instanceof|async|await|yield|true|false|null|undefined|void|this|super|static|get|set|type|interface|enum|implements|declare|namespace|abstract|readonly|keyof|as|satisfies)\b"#, C.keyword),
        (#"`[^`]*`"#,                               C.string),
        (#"'(?:[^'\\]|\\.)*'"#,                     C.string),
        (#""(?:[^"\\]|\\.)*""#,                     C.string),
        (#"//[^\n]*"#,                              C.comment),
        (#"/\*[\s\S]*?\*/"#,                        C.comment),
    ])

    // MARK: - Python

    private static let pythonPasses: [Pass] = compile([
        (#"\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#,   C.number),
        (#"\b[A-Z][a-zA-Z0-9_]*\b"#,               C.type_),
        (#"\b(?:import|from|as|class|def|if|elif|else|for|while|try|except|finally|raise|return|yield|with|pass|break|continue|and|or|not|in|is|lambda|global|nonlocal|True|False|None|async|await)\b"#, C.keyword),
        (#"@[a-zA-Z_][a-zA-Z0-9_]*"#,             C.type_),
        (#"\"\"\"[\s\S]*?\"\"\""#,                  C.string),  // triple-double
        (#"'''[\s\S]*?'''"#,                        C.string),  // triple-single
        (#"'(?:[^'\\]|\\.)*'"#,                     C.string),
        (#""(?:[^"\\]|\\.)*""#,                     C.string),
        (#"#[^\n]*"#,                               C.comment),
    ])

    // MARK: - JSON

    private static let jsonPasses: [Pass] = compile([
        (#"\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#,   C.number),
        (#"\b(?:true|false|null)\b"#,               C.keyword),
        (#""(?:[^"\\]|\\.)*""#,                     C.string),
        // Key strings: lookahead for colon — matches only the key, not the colon
        (#""(?:[^"\\]|\\.)*"(?=\s*:)"#,            C.type_),
    ])

    // MARK: - Markdown

    private static let markdownPasses: [Pass] = compile([
        (#"`[^`\n]+`"#,                             C.comment),  // inline code
        (#"\*\*[^*\n]+\*\*"#,                       C.type_),    // bold
        (#"\*[^*\n]+\*"#,                           C.string),   // italic
        (#"^#{1,6}\s.+"#,                           C.keyword),  // headings
        (#"^```[\s\S]*?^```"#,                      C.comment),  // code fences
    ])

    // MARK: - Regex compiler (errors silently drop the pattern, never crash)

    private static func compile(_ specs: [(String, UIColor)]) -> [Pass] {
        specs.compactMap { pattern, color in
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.anchorsMatchLines, .dotMatchesLineSeparators]
            ) else { return nil }
            return (regex, color)
        }
    }

    // MARK: - Apply

    private static func apply(passes: [Pass], to attr: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: attr.length)
        for pass in passes {
            pass.regex.enumerateMatches(in: attr.string, range: fullRange) { match, _, _ in
                guard let range = match?.range, range.length > 0 else { return }
                attr.addAttribute(.foregroundColor, value: pass.color, range: range)
            }
        }
    }
}

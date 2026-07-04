import Foundation

// MARK: - FindReplaceEngine
// Pure, view-independent find/replace over NSString (UTF-16) ranges.
// Used by EditorContainerView; unit-tested in isolation.

enum FindReplaceEngine {

    struct MatchResult: Equatable {
        let ranges: [NSRange]
        let isInvalidRegex: Bool
    }

    /// All matches of `query` in `text`, in document order.
    /// Regex compile failure → isInvalidRegex = true, empty ranges.
    /// Zero-width matches are excluded.
    static func matches(
        in text: String, query: String, isRegex: Bool, caseSensitive: Bool
    ) -> MatchResult {
        guard !query.isEmpty else {
            return MatchResult(ranges: [], isInvalidRegex: false)
        }
        let nsText = text as NSString
        let full = NSRange(location: 0, length: nsText.length)

        if isRegex {
            var options: NSRegularExpression.Options = []
            if !caseSensitive { options.insert(.caseInsensitive) }
            guard let regex = try? NSRegularExpression(pattern: query, options: options) else {
                return MatchResult(ranges: [], isInvalidRegex: true)
            }
            let ranges = regex.matches(in: text, options: [], range: full)
                .map(\.range)
                .filter { $0.length > 0 }
            return MatchResult(ranges: ranges, isInvalidRegex: false)
        } else {
            var options: NSString.CompareOptions = []
            if !caseSensitive { options.insert(.caseInsensitive) }
            var results: [NSRange] = []
            var searchFrom = full
            while searchFrom.location < nsText.length {
                let found = nsText.range(of: query, options: options, range: searchFrom)
                guard found.location != NSNotFound else { break }
                results.append(found)
                let next = found.location + max(found.length, 1)
                searchFrom = NSRange(location: next, length: nsText.length - next)
            }
            return MatchResult(ranges: results, isInvalidRegex: false)
        }
    }

    /// Replace every match. Invalid regex or no matches → returns text unchanged.
    static func replaceAll(
        in text: String, query: String, replacement: String,
        isRegex: Bool, caseSensitive: Bool
    ) -> String {
        guard !query.isEmpty else { return text }
        let nsText = NSMutableString(string: text)
        let full = NSRange(location: 0, length: nsText.length)

        if isRegex {
            var options: NSRegularExpression.Options = []
            if !caseSensitive { options.insert(.caseInsensitive) }
            guard let regex = try? NSRegularExpression(pattern: query, options: options) else {
                return text
            }
            regex.replaceMatches(in: nsText, options: [], range: full, withTemplate: replacement)
            return nsText as String
        } else {
            // Reverse-order pass so earlier ranges stay valid as we mutate.
            let result = matches(in: text, query: query, isRegex: false, caseSensitive: caseSensitive)
            guard !result.ranges.isEmpty else { return text }
            for range in result.ranges.reversed() {
                nsText.replaceCharacters(in: range, with: replacement)
            }
            return nsText as String
        }
    }

    /// Replace the single match at `matchRange`.
    /// Regex mode resolves `$1`… in `replacement` against that match's captures.
    static func replaceOne(
        in text: String, matchRange: NSRange, query: String,
        replacement: String, isRegex: Bool, caseSensitive: Bool
    ) -> String {
        let nsText = NSMutableString(string: text)
        guard NSMaxRange(matchRange) <= nsText.length else { return text }

        var options: NSRegularExpression.Options = []
        if !caseSensitive { options.insert(.caseInsensitive) }

        let resolved: String
        if isRegex, let regex = try? NSRegularExpression(pattern: query, options: options) {
            let matched = nsText.substring(with: matchRange)
            let localRange = NSRange(location: 0, length: (matched as NSString).length)
            resolved = regex.stringByReplacingMatches(
                in: matched, options: [], range: localRange, withTemplate: replacement
            )
        } else {
            resolved = replacement
        }
        nsText.replaceCharacters(in: matchRange, with: resolved)
        return nsText as String
    }
}

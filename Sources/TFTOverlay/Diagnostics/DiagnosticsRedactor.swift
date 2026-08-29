import Foundation

/// Strips user-identifying strings from diagnostic text before export (#5).
/// Pure and injectable — tests pass synthetic identity values instead of
/// depending on whoever's machine actually runs the suite.
enum DiagnosticsRedactor {
    static func redact(
        _ text: String,
        userName: String = NSUserName(),
        fullName: String = NSFullUserName(),
        homeDirectory: String = NSHomeDirectory()
    ) -> String {
        var result = text

        if !fullName.isEmpty {
            result = result.replacingOccurrences(of: fullName, with: "<redacted-name>")
        }
        if !userName.isEmpty {
            result = result.replacingOccurrences(of: userName, with: "<redacted-user>")
        }
        if !homeDirectory.isEmpty {
            result = result.replacingOccurrences(of: homeDirectory, with: "/Users/<redacted>")
        }
        // Catches any other /Users/<name> path the specific substitutions
        // above didn't (e.g. one logged by a library under a different
        // account name than the current user's).
        result = replacing(pattern: #"/Users/[^/\s]+"#, in: result, with: "/Users/<redacted>")
        result = replacing(
            pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
            in: result,
            with: "<redacted-email>"
        )

        return result
    }

    private static func replacing(pattern: String, in text: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}

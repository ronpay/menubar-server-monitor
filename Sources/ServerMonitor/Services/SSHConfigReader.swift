import Foundation

/// Reads ~/.ssh/config and returns concrete (non-wildcard) Host aliases.
/// We deliberately don't try to support every directive — just enough to
/// power autocomplete in Settings.
enum SSHConfigReader {
    static func listHosts() -> [String] {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh/config")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parseHosts(from: text)
    }

    /// Visible for testing.
    static func parseHosts(from text: String) -> [String] {
        var hosts: [String] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2 else { continue }
            guard parts[0].lowercased() == "host" else { continue }
            for token in parts.dropFirst() {
                let alias = String(token)
                // Skip wildcards and negations — they're patterns, not real hosts.
                if alias.contains("*") || alias.contains("?") || alias.hasPrefix("!") { continue }
                hosts.append(alias)
            }
        }
        // De-duplicate while preserving order.
        var seen = Set<String>()
        return hosts.filter { seen.insert($0).inserted }
    }
}

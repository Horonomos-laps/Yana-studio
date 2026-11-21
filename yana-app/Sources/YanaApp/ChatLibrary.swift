import Foundation

// Pure helpers for the list of past chats: searching their text, a snippet around the match, and a Markdown export.
// No views and no storage here, so they can be checked on their own.

enum ChatLibrary {
	// Lower case, accents removed, and the Vietnamese "đ" read as "d", so "tim kiem" finds "Tìm kiếm".
	static func normalize(_ text: String) -> String {
		text.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "d")
			.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	// Every word of the query must appear somewhere in the title or in the messages; an empty query matches all.
	static func matches(title: String, lines: [String], query: String) -> Bool {
		let words = normalize(query).split(whereSeparator: \.isWhitespace).map(String.init)
		guard !words.isEmpty else { return true }
		let haystack = normalize(([title] + lines).joined(separator: "\n"))
		return words.allSatisfy { haystack.contains($0) }
	}

	// A few words around the first message that holds the first query word, with "…" where it was cut.
	static func snippet(lines: [String], query: String, radius: Int) -> String? {
		guard let word = normalize(query).split(whereSeparator: \.isWhitespace).first.map(String.init) else { return nil }
		for line in lines {
			let flat = line.replacingOccurrences(of: "\n", with: " ")
			guard let range = normalize(flat).range(of: word) else { continue }
			// The folded text can differ in length from the original, so cut by character offsets in the original.
			let offset = min(normalize(flat).distance(from: normalize(flat).startIndex, to: range.lowerBound), max(flat.count - 1, 0))
			let start = max(offset - radius, 0)
			let end = min(offset + word.count + radius, flat.count)
			let slice = String(flat.dropFirst(start).prefix(end - start))
			return (start > 0 ? "…" : "") + slice + (end < flat.count ? "…" : "")
		}
		return nil
	}

	// One chat as a Markdown document: a heading with its title, who and when, then the messages in order.
	static func markdown(title: String, provider: String, model: String?, updated: Date, lines: [(user: Bool, text: String)]) -> String {
		let heading = title.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
		let who = [provider, model].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
		let stamp = ISO8601DateFormatter().string(from: updated)
		var out = "# \(heading.isEmpty ? "Chat" : heading)\n\n"
		out += "_\(who.isEmpty ? "" : who + " · ")\(stamp)_\n\n"
		for line in lines where !line.text.isEmpty {
			out += "**\(line.user ? "Bạn" : "Yana"):**\n\n\(line.text)\n\n"
		}
		return out
	}

	// A file name from a title: no path characters, never empty, at most 80 characters, ending in .md.
	static func fileName(for title: String) -> String {
		let bad = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t")
		var base = title.components(separatedBy: bad).joined(separator: " ").trimmingCharacters(in: .whitespaces)
		while base.hasPrefix(".") { base.removeFirst() }
		base = String(base.prefix(76)).trimmingCharacters(in: .whitespaces)
		return (base.isEmpty ? "chat" : base) + ".md"
	}
}

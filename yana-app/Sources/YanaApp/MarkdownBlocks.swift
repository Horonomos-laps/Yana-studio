import Foundation

// Splits a reply into the blocks the chat draws differently: fenced code (with its language), headings, and the
// text between them. Inline styling inside a text block (bold, links, `code`) is left to AttributedString.
//
// While a reply is still streaming the closing fence has not arrived yet: such a block is returned with
// `closed: false` so it is drawn as code from the first line instead of flashing as text and jumping.

enum MarkdownBlocks {
	enum Block: Equatable {
		case text(String)
		case heading(level: Int, text: String)
		case code(language: String, code: String, closed: Bool)
	}

	private static let maxHeading = 6

	static func parse(_ source: String) -> [Block] {
		var blocks: [Block] = []
		var text: [String] = []
		var code: [String] = []
		var language = ""
		var inCode = false

		func flushText() {
			// Blank lines at the edges of a text run are only spacing.
			var lines = text
			while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeFirst() }
			while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
			if !lines.isEmpty { blocks.append(.text(lines.joined(separator: "\n"))) }
			text = []
		}

		// Swift reads "\r\n" as one character, so it would not split on "\n": normalise first.
		let normalised = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
		for rawLine in normalised.split(separator: "\n", omittingEmptySubsequences: false) {
			let line = String(rawLine)
			if inCode {
				if isFence(line) {
					blocks.append(.code(language: language, code: code.joined(separator: "\n"), closed: true))
					code = []
					inCode = false
				} else {
					code.append(line)
				}
				continue
			}
			if let opened = openingFence(line) {
				flushText()
				language = opened
				inCode = true
			} else if let heading = heading(line) {
				flushText()
				blocks.append(heading)
			} else {
				text.append(line)
			}
		}
		if inCode {
			blocks.append(.code(language: language, code: code.joined(separator: "\n"), closed: false))
		} else {
			flushText()
		}
		return blocks
	}

	// "- item" and "* item" lines drawn with a bullet, keeping their indent; every other line is left as it is.
	static func bulleted(_ text: String) -> String {
		text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
			let indent = line.prefix { $0 == " " || $0 == "\t" }
			let rest = line.dropFirst(indent.count)
			guard rest.hasPrefix("- ") || rest.hasPrefix("* ") else { return String(line) }
			return indent + "•" + rest.dropFirst(1)
		}.joined(separator: "\n")
	}

	// A fence is three backticks at the start of a line (up to three spaces of indent). Anything after them on the
	// opening line is the info string; its first word is the language.
	private static func fenceInfo(_ line: String) -> String? {
		let indent = line.prefix { $0 == " " }.count
		guard indent <= 3 else { return nil }
		let rest = line.dropFirst(indent)
		guard rest.hasPrefix("```") else { return nil }
		return String(rest.drop { $0 == "`" })
	}

	private static func openingFence(_ line: String) -> String? {
		guard let info = fenceInfo(line) else { return nil }
		return info.split(separator: " ").first.map(String.init) ?? ""
	}

	// The closing fence is the backticks alone on the line.
	private static func isFence(_ line: String) -> Bool {
		guard let info = fenceInfo(line) else { return false }
		return info.trimmingCharacters(in: .whitespaces).isEmpty
	}

	private static func heading(_ line: String) -> Block? {
		let hashes = line.prefix { $0 == "#" }.count
		guard (1 ... maxHeading).contains(hashes) else { return nil }
		let rest = line.dropFirst(hashes)
		guard rest.first == " " else { return nil }
		let title = rest.trimmingCharacters(in: .whitespaces)
		return title.isEmpty ? nil : .heading(level: hashes, text: title)
	}
}

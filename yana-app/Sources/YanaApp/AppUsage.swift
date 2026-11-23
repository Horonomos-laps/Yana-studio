import Foundation

// Tokens spent in this app's own chats, read from the saved chats (ChatHistory.swift). yana-rt's ledger, which the
// Usage page also shows, does not hold these, so they are kept apart on the page rather than added to it: nothing
// is counted twice if yana-rt ever starts logging them too. Only token counts are known here, no dollar estimate.
//
// A reply carries the time its numbers arrived. Chats saved before that existed have no such time, so their replies
// count on the day the chat was last updated; that is the one approximation, and the page says so.

struct AppUsageEntry: Equatable {
	let day: String        // UTC date, same form as the ledger's
	let model: String
	let chat: String
	let inputTokens: Int
	let outputTokens: Int
	var tokens: Int { inputTokens + outputTokens }
}

enum AppUsage {
	private static let utcDay: DateFormatter = {
		let f = DateFormatter()
		f.dateFormat = "yyyy-MM-dd"
		f.timeZone = TimeZone(identifier: "UTC")
		f.locale = Locale(identifier: "en_US_POSIX")
		return f
	}()

	static func day(_ date: Date) -> String { utcDay.string(from: date) }

	// One entry per reply that reported tokens, in the order the chats and replies are stored.
	static func entries(from chats: [SavedChat]) -> [AppUsageEntry] {
		chats.flatMap { chat -> [AppUsageEntry] in
			chat.lines.compactMap { line in
				guard !line.user, line.inputTokens + line.outputTokens > 0 else { return nil }
				return AppUsageEntry(day: day(line.at ?? chat.updated), model: chat.model ?? chat.provider,
				                     chat: chat.displayTitle, inputTokens: line.inputTokens, outputTokens: line.outputTokens)
			}
		}
	}

	static func total(_ entries: [AppUsageEntry]) -> (replies: Int, input: Int, output: Int) {
		(entries.count, entries.reduce(0) { $0 + $1.inputTokens }, entries.reduce(0) { $0 + $1.outputTokens })
	}

	static func byDay(_ entries: [AppUsageEntry]) -> [String: Int] {
		Dictionary(grouping: entries, by: \.day).mapValues { $0.reduce(0) { $0 + $1.tokens } }
	}

	static func byModel(_ entries: [AppUsageEntry]) -> [(model: String, replies: Int, tokens: Int)] {
		Dictionary(grouping: entries, by: \.model)
			.map { (model: $0.key, replies: $0.value.count, tokens: $0.value.reduce(0) { $0 + $1.tokens }) }
			.sorted { $0.tokens > $1.tokens }
	}

	// The chats that spent the most, for the "where did it go" list.
	static func topChats(_ entries: [AppUsageEntry], limit: Int) -> [(chat: String, tokens: Int)] {
		Dictionary(grouping: entries, by: \.chat)
			.map { (chat: $0.key, tokens: $0.value.reduce(0) { $0 + $1.tokens }) }
			.sorted { $0.tokens > $1.tokens }
			.prefix(limit).map { $0 }
	}
}

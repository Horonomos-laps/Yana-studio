import Foundation

// How the chat sidebar groups saved chats: "Pinned" first, then "Recent". No views and no storage here.
// While searching, both groups show every match; otherwise a long Recent list is cut to a limit with a
// "show more" row, so the sidebar stays short.

struct ChatSection: Identifiable, Equatable {
	enum Kind: String { case pinned, recent }
	let kind: Kind
	let chats: [SavedChat]
	// Chats left out of `chats` by the limit (only ever for Recent).
	let hidden: Int
	var id: String { kind.rawValue }
}

enum ChatSections {
	// YANA_RECENT_LIMIT lowers it so the "Show more" row can be checked without 30 chats on screen.
	static var recentLimit: Int {
		ProcessInfo.processInfo.environment["YANA_RECENT_LIMIT"].flatMap(Int.init).flatMap { $0 > 0 ? $0 : nil } ?? 30
	}

	// `chats` is the saved list, any order. Empty groups are left out.
	static func build(chats: [SavedChat], query: String, showAllRecent: Bool, limit: Int = recentLimit) -> [ChatSection] {
		let searching = !ChatLibrary.normalize(query).isEmpty
		let matching = chats.filter { ChatLibrary.matches(title: $0.displayTitle, lines: $0.lines.map(\.text), query: query) }
		let newestFirst: (SavedChat, SavedChat) -> Bool = { $0.updated > $1.updated }
		let pinned = matching.filter(\.isPinned).sorted(by: newestFirst)
		let recent = matching.filter { !$0.isPinned }.sorted(by: newestFirst)
		let cut = !searching && !showAllRecent && recent.count > limit
		var out: [ChatSection] = []
		if !pinned.isEmpty { out.append(ChatSection(kind: .pinned, chats: pinned, hidden: 0)) }
		if !recent.isEmpty {
			out.append(ChatSection(kind: .recent, chats: cut ? Array(recent.prefix(limit)) : recent, hidden: cut ? recent.count - limit : 0))
		}
		return out
	}
}

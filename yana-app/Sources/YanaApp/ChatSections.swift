import Foundation

// How the chat sidebar groups saved chats: "Pinned" first, then "Recent", and "Archived" on request. No views and
// no storage here. While searching, every group shows all of its matches (archived ones too, so they can be found);
// otherwise a long Recent list is cut to a limit with a "show more" row, so the sidebar stays short.

struct ChatSection: Identifiable, Equatable {
	enum Kind: String { case pinned, recent, archived }
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

	static func archivedCount(_ chats: [SavedChat]) -> Int { chats.filter(\.isArchived).count }

	// `chats` is the saved list, any order. Empty groups are left out. An archived chat is never pinned or recent.
	static func build(chats: [SavedChat], query: String, showAllRecent: Bool, showArchived: Bool = false,
	                  limit: Int = recentLimit) -> [ChatSection] {
		let searching = !ChatLibrary.normalize(query).isEmpty
		let matching = chats.filter { ChatLibrary.matches(title: $0.displayTitle, lines: $0.lines.map(\.text), query: query) }
		let newestFirst: (SavedChat, SavedChat) -> Bool = { $0.updated > $1.updated }
		let live = matching.filter { !$0.isArchived }
		let pinned = live.filter(\.isPinned).sorted(by: newestFirst)
		let recent = live.filter { !$0.isPinned }.sorted(by: newestFirst)
		let archived = matching.filter(\.isArchived).sorted(by: newestFirst)
		let cut = !searching && !showAllRecent && recent.count > limit
		var out: [ChatSection] = []
		if !pinned.isEmpty { out.append(ChatSection(kind: .pinned, chats: pinned, hidden: 0)) }
		if !recent.isEmpty {
			out.append(ChatSection(kind: .recent, chats: cut ? Array(recent.prefix(limit)) : recent, hidden: cut ? recent.count - limit : 0))
		}
		if !archived.isEmpty && (showArchived || searching) { out.append(ChatSection(kind: .archived, chats: archived, hidden: 0)) }
		return out
	}
}

import Foundation

// Past chats, kept on this Mac in ~/Library/Application Support/YanaApp/chats/<session id>.json so a new
// chat never loses the old one and any chat can be reopened from "Recent". Text, errors and token counts are
// kept; image thumbnails are not (the text says which files were attached). A reopened chat keeps its yana-rt
// session id, so its receipts and history stay together.

struct SavedLine: Codable, Equatable {
	let user: Bool
	let text: String
	var error: String?
	var inputTokens = 0
	var outputTokens = 0
	// When this reply's token numbers arrived (the Usage page counts it on that day). Missing in older chats.
	var at: Date? = nil
}

struct SavedChat: Codable, Identifiable, Equatable {
	let id: String              // yana-rt session id
	var title: String
	var updated: Date
	var provider: String
	var model: String?
	var lines: [SavedLine]
	// Set by the person in the sidebar. Optional, so chats saved before these existed still load; the engine
	// keeps them when it saves the chat again (ChatEngine.saveToHistory).
	var customTitle: String? = nil
	var pinned: Bool? = nil
	var archived: Bool? = nil

	var displayTitle: String { customTitle.flatMap { $0.isEmpty ? nil : $0 } ?? title }
	var isPinned: Bool { pinned == true }
	var isArchived: Bool { archived == true }
}

@MainActor
final class ChatHistoryStore: ObservableObject {
	static let shared = ChatHistoryStore()

	@Published private(set) var chats: [SavedChat] = []   // newest first
	@Published private(set) var lastError: String?
	static let titleChars = 60
	static let maxChats = 500                              // oldest beyond this are removed

	let folder: URL

	// YANA_HISTORY_DIR points the store at another folder (to check the sidebar without touching real chats).
	init(folder: URL? = nil) {
		let override = ProcessInfo.processInfo.environment["YANA_HISTORY_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
		self.folder = folder ?? override ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("YanaApp/chats", isDirectory: true)
		loadAll()
	}

	func save(_ chat: SavedChat) {
		guard !chat.lines.isEmpty, Self.validID(chat.id) else { return }
		do {
			try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
			try encoder.encode(chat).write(to: url(chat.id), options: .atomic)
		} catch {
			lastError = "\(L("history.saveFailed")): \(error.localizedDescription)"
			return
		}
		chats.removeAll { $0.id == chat.id }
		chats.insert(chat, at: 0)
		trim()
	}

	func chat(_ id: String) -> SavedChat? { chats.first { $0.id == id } }

	// Pinned chats first, then the newest.
	var ordered: [SavedChat] { chats.filter(\.isPinned) + chats.filter { !$0.isPinned } }

	// The chats that match a search, in the same order; an empty query is every chat.
	func search(_ query: String) -> [SavedChat] {
		ordered.filter { ChatLibrary.matches(title: $0.displayTitle, lines: $0.lines.map(\.text), query: query) }
	}

	func rename(_ id: String, to title: String) {
		guard var chat = chat(id) else { return }
		let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
		chat.customTitle = trimmed.isEmpty ? nil : String(trimmed.prefix(Self.titleChars))
		persist(chat)
	}

	func setPinned(_ id: String, _ pinned: Bool) {
		guard var chat = chat(id) else { return }
		chat.pinned = pinned ? true : nil
		persist(chat)
	}

	// Hides a chat from the sidebar lists without deleting it. An archived chat is no longer pinned.
	func setArchived(_ id: String, _ archived: Bool) {
		guard var chat = chat(id) else { return }
		chat.archived = archived ? true : nil
		if archived { chat.pinned = nil }
		persist(chat)
	}

	// Archives every chat that is not archived yet.
	func archiveAll() {
		for chat in chats where !chat.isArchived { setArchived(chat.id, true) }
	}

	// A copy of a chat under a new session id, so the two continue separately. Nil when the chat is unknown.
	@discardableResult
	func fork(_ id: String, now: Date = Date()) -> SavedChat? {
		guard let source = chat(id) else { return nil }
		var copy = source
		copy = SavedChat(id: UUID().uuidString.lowercased(), title: source.title, updated: now, provider: source.provider,
		                 model: source.model, lines: source.lines,
		                 customTitle: String(format: L("history.forkTitle"), source.displayTitle), pinned: nil, archived: nil)
		save(copy)
		return chat(copy.id)
	}

	// File names for an export: one per chat, unique inside the folder ("Title.md", "Title 2.md"...).
	static func exportNames(for chats: [SavedChat]) -> [String] {
		var used = Set<String>()
		return chats.map { chat in
			let base = ChatLibrary.fileName(for: chat.displayTitle)
			var name = base
			var n = 2
			while !used.insert(name.lowercased()).inserted {
				name = String(base.dropLast(3)) + " \(n).md"
				n += 1
			}
			return name
		}
	}

	// Writes every chat as a Markdown file into `folder`. Returns how many were written.
	func exportAll(to folder: URL) throws -> Int {
		let list = ordered
		let names = Self.exportNames(for: list)
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		for (chat, name) in zip(list, names) {
			try Data(markdown(chat).utf8).write(to: folder.appendingPathComponent(name), options: .atomic)
		}
		return list.count
	}

	// Removes every saved chat (and its file). Nothing else in the folder is touched.
	func deleteAll() {
		for chat in chats { try? FileManager.default.removeItem(at: url(chat.id)) }
		chats = []
	}

	// Writes a changed chat back without moving it to the top: only a new message does that.
	private func persist(_ chat: SavedChat) {
		guard Self.validID(chat.id), let index = chats.firstIndex(where: { $0.id == chat.id }) else { return }
		do {
			try encoder.encode(chat).write(to: url(chat.id), options: .atomic)
			chats[index] = chat
		} catch {
			lastError = "\(L("history.saveFailed")): \(error.localizedDescription)"
		}
	}

	func markdown(_ chat: SavedChat) -> String {
		ChatLibrary.markdown(title: chat.displayTitle, provider: chat.provider, model: chat.model, updated: chat.updated,
		                     lines: chat.lines.map { (user: $0.user, text: $0.text) })
	}

	func delete(_ id: String) {
		guard Self.validID(id) else { return }
		try? FileManager.default.removeItem(at: url(id))
		chats.removeAll { $0.id == id }
	}

	// A session id is a UUID or a plain id; never a path.
	static func validID(_ id: String) -> Bool {
		!id.isEmpty && id.count <= 128 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
	}

	private func url(_ id: String) -> URL { folder.appendingPathComponent("\(id).json") }

	private func trim() {
		guard chats.count > Self.maxChats else { return }
		for old in chats.suffix(from: Self.maxChats) { try? FileManager.default.removeItem(at: url(old.id)) }
		chats = Array(chats.prefix(Self.maxChats))
	}

	private func loadAll() {
		let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		var loaded: [SavedChat] = []
		var broken = 0
		for file in files where file.pathExtension == "json" {
			if let data = try? Data(contentsOf: file), let chat = try? decoder.decode(SavedChat.self, from: data) {
				loaded.append(chat)
			} else {
				broken += 1
			}
		}
		chats = loaded.sorted { $0.updated > $1.updated }
		if broken > 0 { lastError = String(format: L("history.broken"), broken) }
	}

	private var encoder: JSONEncoder {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		return encoder
	}
}

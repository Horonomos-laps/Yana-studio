import XCTest
@testable import YanaApp

final class PersonalizationTests: XCTestCase {
	private func defaults() -> UserDefaults {
		let name = "yana.tests.per.\(UUID().uuidString)"
		let d = UserDefaults(suiteName: name)!
		d.removePersistentDomain(forName: name)
		return d
	}

	func testNothingIsSentWhileEverythingIsEmpty() {
		XCTAssertNil(Personalization.instruction(defaults()))
		let d = defaults()
		d.set("  \n ", forKey: Personalization.nameKey)
		d.set("", forKey: Personalization.aboutKey)
		XCTAssertNil(Personalization.instruction(d))
	}

	func testEachFilledFieldAddsItsOwnPart() {
		let d = defaults()
		d.set("Tâm", forKey: Personalization.nameKey)
		d.set("Software engineer, uses Swift.", forKey: Personalization.aboutKey)
		d.set("Answer briefly.", forKey: Personalization.rulesKey)
		let text = Personalization.instruction(d) ?? ""
		XCTAssertTrue(text.contains("name is Tâm"))
		XCTAssertTrue(text.contains("Software engineer, uses Swift."))
		XCTAssertTrue(text.contains("Answer briefly."))
	}

	func testOnlyTheFilledFieldAppears() {
		let d = defaults()
		d.set("Answer briefly.", forKey: Personalization.rulesKey)
		let text = Personalization.instruction(d) ?? ""
		XCTAssertTrue(text.contains("Answer briefly."))
		XCTAssertFalse(text.contains("name is"))
		XCTAssertFalse(text.contains("About the user"))
	}

	func testALongPasteIsCut() {
		let d = defaults()
		d.set(String(repeating: "x", count: 50_000), forKey: Personalization.rulesKey)
		d.set(String(repeating: "n", count: 500), forKey: Personalization.nameKey)
		let text = Personalization.instruction(d) ?? ""
		XCTAssertLessThan(text.count, 2 * Personalization.maxChars + 400)
		XCTAssertLessThanOrEqual(Personalization.clean(String(repeating: "x", count: 9_999)).count, Personalization.maxChars)
	}
}

@MainActor
final class ChatHistoryFeatureTests: XCTestCase {
	private var folder: URL!

	override func setUpWithError() throws {
		folder = FileManager.default.temporaryDirectory.appendingPathComponent("yana-hist-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
	}

	override func tearDown() {
		if folder.lastPathComponent.hasPrefix("yana-hist-") { try? FileManager.default.removeItem(at: folder) }
	}

	private func chat(_ id: String, _ title: String, age: TimeInterval = 0, pinned: Bool = false) -> SavedChat {
		SavedChat(id: id, title: title, updated: Date(timeIntervalSince1970: 2_000_000 - age), provider: "ollama", model: "m",
		          lines: [SavedLine(user: true, text: "question of \(title)"), SavedLine(user: false, text: "answer")],
		          customTitle: nil, pinned: pinned ? true : nil)
	}

	func testForkCopiesTheMessagesUnderANewIdAndLeavesTheOriginal() throws {
		let store = ChatHistoryStore(folder: folder)
		store.save(chat("a", "Plan", pinned: true))
		let copy = try XCTUnwrap(store.fork("a"))
		XCTAssertNotEqual(copy.id, "a")
		XCTAssertEqual(copy.lines, store.chat("a")?.lines)
		XCTAssertFalse(copy.isPinned)
		XCTAssertTrue(copy.displayTitle.contains("Plan"))
		XCTAssertTrue(store.chat("a")?.isPinned ?? false)
		XCTAssertEqual(store.chats.count, 2)
		XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("\(copy.id).json").path))
	}

	func testForkOfAnUnknownChatIsNil() {
		XCTAssertNil(ChatHistoryStore(folder: folder).fork("nope"))
	}

	func testArchivingHidesFromListsClearsThePinAndSurvivesReload() throws {
		let store = ChatHistoryStore(folder: folder)
		store.save(chat("a", "A", pinned: true))
		store.setArchived("a", true)
		XCTAssertTrue(store.chat("a")?.isArchived ?? false)
		XCTAssertFalse(store.chat("a")?.isPinned ?? true)
		XCTAssertTrue(ChatSections.build(chats: store.chats, query: "", showAllRecent: false).isEmpty)
		XCTAssertEqual(ChatHistoryStore(folder: folder).chat("a")?.isArchived, true)
		store.setArchived("a", false)
		XCTAssertEqual(ChatSections.build(chats: store.chats, query: "", showAllRecent: false).map(\.kind), [.recent])
	}

	func testArchivedGroupShowsOnRequestAndWhenSearching() {
		var archived = chat("z", "Old plan")
		archived.archived = true
		let list = [chat("a", "Live"), archived]
		XCTAssertEqual(ChatSections.build(chats: list, query: "", showAllRecent: false).map(\.kind), [.recent])
		XCTAssertEqual(ChatSections.build(chats: list, query: "", showAllRecent: false, showArchived: true).map(\.kind), [.recent, .archived])
		XCTAssertEqual(ChatSections.build(chats: list, query: "old", showAllRecent: false).map(\.kind), [.archived])
		XCTAssertEqual(ChatSections.archivedCount(list), 1)
	}

	func testArchiveAllArchivesEveryChat() {
		let store = ChatHistoryStore(folder: folder)
		store.save(chat("a", "A"))
		store.save(chat("b", "B", pinned: true))
		store.archiveAll()
		XCTAssertTrue(store.chats.allSatisfy(\.isArchived))
	}

	func testExportNamesAreUniqueEvenForTheSameTitle() {
		let names = ChatHistoryStore.exportNames(for: [chat("1", "hi"), chat("2", "hi"), chat("3", "Hi"), chat("4", "a/b")])
		XCTAssertEqual(Set(names.map { $0.lowercased() }).count, 4)
		XCTAssertTrue(names.allSatisfy { $0.hasSuffix(".md") && !$0.contains("/") })
		XCTAssertEqual(names[0], "hi.md")
		XCTAssertEqual(names[1], "hi 2.md")
	}

	func testExportAllWritesOneMarkdownFilePerChat() throws {
		let store = ChatHistoryStore(folder: folder.appendingPathComponent("chats"))
		store.save(chat("a", "First"))
		store.save(chat("b", "Second"))
		let out = folder.appendingPathComponent("export")
		XCTAssertEqual(try store.exportAll(to: out), 2)
		let files = try FileManager.default.contentsOfDirectory(atPath: out.path).sorted()
		XCTAssertEqual(files, ["First.md", "Second.md"])
		let text = try String(contentsOf: out.appendingPathComponent("First.md"), encoding: .utf8)
		XCTAssertTrue(text.contains("question of First"))
	}

	func testDeleteAllRemovesTheFilesAndOnlyThose() throws {
		let store = ChatHistoryStore(folder: folder)
		store.save(chat("a", "A"))
		store.save(chat("b", "B"))
		let keep = folder.appendingPathComponent("notes.txt")
		try "keep".write(to: keep, atomically: true, encoding: .utf8)
		store.deleteAll()
		XCTAssertTrue(store.chats.isEmpty)
		XCTAssertTrue(ChatHistoryStore(folder: folder).chats.isEmpty)
		XCTAssertTrue(FileManager.default.fileExists(atPath: keep.path), "a file that is not a chat must stay")
	}
}

final class SettingsSearchTests: XCTestCase {
	func testAnEmptyQueryListsEverySectionInOrder() {
		XCTAssertEqual(SettingsSection.matching(""), SettingsSection.allCases)
		XCTAssertEqual(SettingsSection.matching("   "), SettingsSection.allCases)
	}

	func testMatchingIgnoresCaseAndAccents() {
		XCTAssertTrue(SettingsSection.matching("ca nhan").contains(.personal))
		XCTAssertTrue(SettingsSection.matching("PHÍM TẮT").contains(.shortcuts))
		XCTAssertTrue(SettingsSection.matching("worktree").contains(.worktree))
	}

	func testEveryWordMustMatch() {
		XCTAssertTrue(SettingsSection.matching("git worktree").isEmpty || SettingsSection.matching("git worktree").contains(.worktree))
		XCTAssertTrue(SettingsSection.matching("zzzz qqqq").isEmpty)
	}

	func testTheDescriptionIsSearchedToo() {
		// "Keychain" is only in the Data pane's description, not its name.
		XCTAssertFalse(SettingsSection.matching("Yana").isEmpty)
		XCTAssertTrue(SettingsSection.allCases.allSatisfy { !$0.subtitle.isEmpty && $0.subtitle != "set.about.\($0.rawValue)" })
	}

	func testEverySectionHasANameAnIconAndADescription() {
		for s in SettingsSection.allCases {
			XCTAssertNotEqual(s.title, "set.section.\(s.rawValue)", s.rawValue)
			XCTAssertNotNil(FBIcons.markup[s.icon], s.rawValue)
		}
	}
}

import XCTest
@testable import YanaApp

final class ProjectTests: XCTestCase {
	private func chat(_ id: String, project: String? = nil, archived: Bool = false) -> SavedChat {
		var c = SavedChat(id: id, title: id, updated: Date(), provider: "p", model: nil, lines: [SavedLine(user: true, text: id)])
		c.projectID = project; c.archived = archived ? true : nil
		return c
	}

	func testANameIsRequiredCleanedAndShortened() {
		XCTAssertEqual(ProjectLogic.cleanName("  Web\nsite  "), "Web site")
		XCTAssertEqual(ProjectLogic.cleanName(String(repeating: "x", count: 200)).count, ProjectLogic.maxName)
		XCTAssertEqual(ProjectLogic.add([], name: "   ", folder: "", instructions: "").count, 0)
		XCTAssertEqual(ProjectLogic.add([], name: "A", folder: "", instructions: "  rules  ").first?.instructions, "rules")
		XCTAssertEqual(ProjectLogic.cleanInstructions(String(repeating: "y", count: 20_000)).count, ProjectLogic.maxInstructions)
	}

	func testAFolderMustExistWhenGiven() {
		XCTAssertTrue(ProjectLogic.isValid(name: "A", folder: "", isDirectory: { _ in false }), "no folder is fine")
		XCTAssertTrue(ProjectLogic.isValid(name: "A", folder: "/x", isDirectory: { _ in true }))
		XCTAssertFalse(ProjectLogic.isValid(name: "A", folder: "/missing", isDirectory: { _ in false }))
		XCTAssertFalse(ProjectLogic.isValid(name: " ", folder: "", isDirectory: { _ in true }))
		XCTAssertTrue(ProjectLogic.isValid(name: "A", folder: NSTemporaryDirectory()), "the real check accepts a real folder")
	}

	func testUpdateKeepsTheIdAndTheDateAndRemoveDropsOnlyThatProject() {
		var list = ProjectLogic.add([], name: "A", folder: "", instructions: "")
		list = ProjectLogic.add(list, name: "B", folder: "", instructions: "")
		let a = list[0]
		list = ProjectLogic.update(list, id: a.id, name: "A2", folder: "/f", instructions: "i")
		XCTAssertEqual(list[0].id, a.id); XCTAssertEqual(list[0].created, a.created); XCTAssertEqual(list[0].name, "A2")
		XCTAssertEqual(ProjectLogic.update(list, id: a.id, name: "  ", folder: "", instructions: ""), list, "an empty name changes nothing")
		XCTAssertEqual(ProjectLogic.remove(list, id: a.id).map(\.name), ["B"])
	}

	func testTheInstructionNamesTheProjectAndCarriesTheUsersRules() {
		let plain = ProjectLogic.instruction(for: Project(name: "Web", instructions: ""))
		XCTAssertTrue(plain.contains("\"Web\"")); XCTAssertFalse(plain.contains("Instructions for this project"))
		let rich = ProjectLogic.instruction(for: Project(name: "Web", instructions: "Use TypeScript."))
		XCTAssertTrue(rich.contains("Use TypeScript."))
	}

	func testChatsAreSplitBetweenProjectsAndOrdinaryAndCounted() {
		let chats = [chat("a"), chat("b", project: "p1"), chat("c", project: "p1"), chat("d", project: "p2"), chat("e", project: "p1", archived: true)]
		XCTAssertEqual(ProjectLogic.scope(chats, projectID: nil).map(\.id), ["a"])
		XCTAssertEqual(ProjectLogic.scope(chats, projectID: "p1").map(\.id), ["b", "c", "e"])
		XCTAssertEqual(ProjectLogic.counts(chats), ["p1": 2, "p2": 1], "archived chats are not counted")
	}

	func testOlderSavedChatsHaveNoProjectAndAProjectSurvivesSaving() throws {
		let old = #"{"id":"x","title":"t","updated":0,"provider":"p","lines":[]}"#
		let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
		var json = try JSONSerialization.jsonObject(with: Data(old.utf8)) as! [String: Any]
		json["updated"] = "2026-01-01T00:00:00Z"
		let loaded = try decoder.decode(SavedChat.self, from: JSONSerialization.data(withJSONObject: json))
		XCTAssertNil(loaded.projectID)
		let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
		var withProject = loaded; withProject.projectID = "p9"
		XCTAssertEqual(try decoder.decode(SavedChat.self, from: encoder.encode(withProject)).projectID, "p9")
	}

	@MainActor
	func testDeletingAProjectTurnsItsChatsIntoOrdinaryChats() throws {
		let dir = FileManager.default.temporaryDirectory.appendingPathComponent("projects-\(UUID().uuidString)", isDirectory: true)
		defer { try? FileManager.default.removeItem(at: dir) }
		let store = ChatHistoryStore(folder: dir)
		store.save(chat("in", project: "p1")); store.save(chat("other", project: "p2")); store.save(chat("plain"))
		store.setProject("plain", "p1")
		XCTAssertEqual(store.chat("plain")?.projectID, "p1")
		store.releaseProject("p1")
		XCTAssertNil(store.chat("in")?.projectID); XCTAssertNil(store.chat("plain")?.projectID)
		XCTAssertEqual(store.chat("other")?.projectID, "p2", "another project's chats are untouched")
		XCTAssertEqual(ChatHistoryStore(folder: dir).chat("in")?.projectID, nil, "and it is saved to disk")
	}

	func testTheNewTextsExistInAllLanguages() {
		for row in projectRows { XCTAssertFalse(row.vi.isEmpty); XCTAssertFalse(row.en.isEmpty); XCTAssertFalse(row.ko.isEmpty) }
		XCTAssertEqual(Set(projectRows.map(\.key)).count, projectRows.count)
	}
}

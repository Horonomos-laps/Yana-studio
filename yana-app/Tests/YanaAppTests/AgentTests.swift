import XCTest
@testable import YanaApp

final class AgentTests: XCTestCase {
	private let now = Date(timeIntervalSince1970: 1_000_000)
	private func event(_ name: String, session: String = "s1", cwd: String = "/Users/x/Yana-AI", extra: [String: Any] = [:]) -> [String: Any] {
		var json: [String: Any] = ["hook_event_name": name, "session_id": session, "cwd": cwd]
		for (k, v) in extra { json[k] = v }
		return json
	}

	func testAPromptStartsWorkAndToolEventsKeepItGoingButNeverStartASession() {
		var list = AgentEvents.apply([], json: event("UserPromptSubmit", extra: ["prompt": "Sửa\nlỗi"]), now: now, frontmost: "link.vutam.yana.studio")
		XCTAssertEqual(list.count, 1); XCTAssertEqual(list[0].state, .working); XCTAssertEqual(list[0].message, "Sửa lỗi")
		XCTAssertEqual(list[0].project, "Yana-AI"); XCTAssertEqual(list[0].appBundleID, "link.vutam.yana.studio")
		list = AgentEvents.apply(list, json: event("PostToolUse"), now: now.addingTimeInterval(5))
		XCTAssertEqual(list[0].updated, now.addingTimeInterval(5)); XCTAssertEqual(list[0].message, "Sửa lỗi")
		XCTAssertTrue(AgentEvents.apply([], json: event("PostToolUse", session: "unknown"), now: now).isEmpty)
	}

	func testOnlyRealQuestionsMakeItWait() {
		let working = AgentEvents.apply([], json: event("UserPromptSubmit"), now: now)
		XCTAssertEqual(AgentEvents.apply(working, json: event("Notification", extra: ["notification_type": "permission_prompt", "message": "Run rm?"]), now: now)[0].state, .waiting)
		XCTAssertEqual(AgentEvents.apply(working, json: event("Notification", extra: ["message": "Claude is waiting for your input"]), now: now)[0].state, .working,
		               "the idle reminder is not a question")
		XCTAssertEqual(AgentEvents.apply(working, json: event("Notification", extra: ["notification_type": "idle_prompt"]), now: now)[0].state, .working)
		XCTAssertTrue(AgentEvents.needsYou(["message": "Allow this command?"])); XCTAssertFalse(AgentEvents.needsYou([:]))
	}

	func testStopFinishesAndTheEndOfASessionRemovesIt() {
		var list = AgentEvents.apply([], json: event("UserPromptSubmit"), now: now)
		list = AgentEvents.apply(list, json: event("Stop"), now: now)
		XCTAssertEqual(list[0].state, .done)
		list = AgentEvents.apply(list, json: event("SessionEnd"), now: now)
		XCTAssertTrue(list.isEmpty)
		XCTAssertEqual(AgentEvents.apply([], json: ["hook_event_name": "Unknown"], now: now), [], "unknown events change nothing")
		XCTAssertEqual(AgentEvents.apply([], json: ["nothing": 1], now: now), [])
	}

	func testCodexReportsOnlyAFinishedTurn() {
		let list = AgentEvents.apply([], json: ["type": "agent-turn-complete", "thread-id": "t9", "cwd": "/a/b", "last-assistant-message": "Done."], now: now)
		XCTAssertEqual(list.first?.tool, .codex); XCTAssertEqual(list.first?.state, .done); XCTAssertEqual(list.first?.message, "Done.")
		XCTAssertTrue(AgentEvents.apply([], json: ["type": "something-else"], now: now).isEmpty)
	}

	func testSilentSessionsExpireAtTheirOwnLimitsAndTheOverallStateFavorsWaiting() {
		let working = AgentSession(id: "w", tool: .claude, cwd: "/a", state: .working, message: nil, updated: now, appBundleID: nil)
		var waiting = working; waiting.id = "q"; waiting.state = .waiting
		var done = working; done.id = "d"; done.state = .done
		let later = now.addingTimeInterval(AgentEvents.doneTimeout + 1)
		XCTAssertEqual(AgentEvents.expire([working, waiting, done], now: later).map(\.id), ["w", "q"])
		XCTAssertEqual(AgentEvents.expire([working, waiting], now: now.addingTimeInterval(AgentEvents.workingTimeout + 1)).map(\.id), ["q"])
		XCTAssertEqual(AgentEvents.overall([working, waiting]), .waiting); XCTAssertEqual(AgentEvents.overall([working]), .working)
		XCTAssertNil(AgentEvents.overall([done])); XCTAssertNil(AgentEvents.overall([]))
	}

	func testConnectAddsOneHookPerEventKeepsEverythingElseAndIsRepeatable() {
		let mine: [String: Any] = ["theme": "dark", "hooks": ["Stop": [["hooks": [["type": "command", "command": "echo hi"]]]]]]
		let once = AgentHooks.connect(mine)
		XCTAssertTrue(AgentHooks.isConnected(once)); XCTAssertFalse(AgentHooks.isConnected(mine))
		XCTAssertEqual(once["theme"] as? String, "dark")
		let stop = (once["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
		XCTAssertEqual(stop?.count, 2, "the person's own Stop hook stays beside ours")
		let twice = AgentHooks.connect(once)
		XCTAssertEqual(((twice["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]])?.count, 2, "connecting again adds nothing")
		XCTAssertEqual((((once["hooks"] as? [String: Any])?["PostToolUse"] as? [[String: Any]])?.first?["matcher"]) as? String, "*")
	}

	func testDisconnectRemovesExactlyWhatWasAdded() throws {
		let mine: [String: Any] = ["hooks": ["Stop": [["hooks": [["type": "command", "command": "echo hi"]]]]]]
		let back = AgentHooks.disconnect(AgentHooks.connect(mine))
		XCTAssertEqual(NSDictionary(dictionary: back), NSDictionary(dictionary: mine))
		XCTAssertNil(AgentHooks.disconnect(AgentHooks.connect([:]))["hooks"], "nothing of ours and nothing else: no empty hooks")
		XCTAssertTrue(AgentHooks.command.contains(AgentHooks.marker))
		XCTAssertFalse(AgentHooks.command.contains("curl"), "the hook never uses the network")
	}

	func testTheFileIsBackedUpFirstWrittenThroughALinkAndNeverReplacedWhenUnreadable() throws {
		let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hooks-\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: dir) }
		let real = dir.appendingPathComponent("real.json"), link = dir.appendingPathComponent("settings.json")
		try Data(#"{"model":"x"}"#.utf8).write(to: real)
		try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
		try AgentHooks.connect(at: link)
		XCTAssertTrue(AgentHooks.isConnected(at: link)); XCTAssertEqual(try AgentHooks.read(link)["model"] as? String, "x")
		XCTAssertNotNil(try? FileManager.default.destinationOfSymbolicLink(atPath: link.path), "still a link")
		let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.contains("yana-backup") }
		XCTAssertEqual(backups.count, 1)
		try AgentHooks.disconnect(at: link); XCTAssertFalse(AgentHooks.isConnected(at: link))
		XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.contains("yana-backup") }.count, 2,
		               "two changes in the same second keep two different backups")

		let bad = dir.appendingPathComponent("bad.json")
		try Data("not json {".utf8).write(to: bad)
		XCTAssertThrowsError(try AgentHooks.connect(at: bad)); XCTAssertEqual(try String(contentsOf: bad, encoding: .utf8), "not json {")
		XCTAssertEqual(try AgentHooks.read(dir.appendingPathComponent("missing.json")).count, 0, "a missing file reads as empty")
	}
}

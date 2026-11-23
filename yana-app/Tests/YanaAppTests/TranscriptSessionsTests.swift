import XCTest
@testable import YanaApp

final class TranscriptSessionsTests: XCTestCase {
	private let now = Date(timeIntervalSince1970: 2_000_000)
	private func line(_ type: String, tool: Bool = false, cwd: String = "/Users/x/Yana-AI") -> String {
		let content = tool ? #"[{"type":"tool_use","name":"Bash"}]"# : #"[{"type":"text","text":"hi"}]"#
		return #"{"type":"\#(type)","cwd":"\#(cwd)","message":{"role":"\#(type)","content":\#(content)}}"#
	}

	func testTheTailGivesTheFolderAndWhatTheLastEntryWas() {
		let tail = ["cut off line {\"typ", line("user"), #"{"type":"summary","summary":"x"}"#, line("assistant", tool: true)].joined(separator: "\n")
		let info = TranscriptSessions.parse(tail: tail, id: "s1", modified: now)
		XCTAssertEqual(info.cwd, "/Users/x/Yana-AI"); XCTAssertEqual(info.lastRole, "assistant"); XCTAssertTrue(info.lastHadToolUse)
		XCTAssertNil(TranscriptSessions.parse(tail: "garbage\n{}", id: "s", modified: now).lastRole)
	}

	func testALogWrittenAMomentAgoIsAtWork() {
		let info = TranscriptInfo(id: "s", cwd: "/a/Yana-AI", lastRole: "assistant", lastHadToolUse: false, modified: now.addingTimeInterval(-3))
		XCTAssertEqual(TranscriptSessions.session(from: info, now: now)?.state, .working)
		XCTAssertEqual(TranscriptSessions.session(from: info, now: now)?.project, "Yana-AI")
		XCTAssertEqual(TranscriptSessions.session(from: info, now: now)?.tool, .claude)
	}

	func testAFinishedAnswerIsDoneForTwoMinutesThenGone() {
		let info = TranscriptInfo(id: "s", cwd: "", lastRole: "assistant", lastHadToolUse: false, modified: now.addingTimeInterval(-30))
		XCTAssertEqual(TranscriptSessions.session(from: info, now: now)?.state, .done)
		XCTAssertNil(TranscriptSessions.session(from: info, now: now.addingTimeInterval(200)))
	}

	func testAPendingToolOrAPromptJustSentStaysAtWorkForALittleLonger() {
		let tool = TranscriptInfo(id: "s", cwd: "", lastRole: "assistant", lastHadToolUse: true, modified: now.addingTimeInterval(-40))
		XCTAssertEqual(TranscriptSessions.session(from: tool, now: now)?.state, .working)
		XCTAssertNil(TranscriptSessions.session(from: tool, now: now.addingTimeInterval(100)), "after 90 s with nothing it is not shown")
		let asked = TranscriptInfo(id: "s", cwd: "", lastRole: "user", lastHadToolUse: false, modified: now.addingTimeInterval(-30))
		XCTAssertEqual(TranscriptSessions.session(from: asked, now: now)?.state, .working)
		XCTAssertNil(TranscriptSessions.session(from: TranscriptInfo(id: "s", cwd: "", lastRole: nil, lastHadToolUse: false, modified: now), now: now))
	}

	func testAHookSessionKeepsItsWaitingStateAndAnOlderHookYieldsToAFresherLog() {
		let hook = AgentSession(id: "s", tool: .claude, cwd: "/a", state: .waiting, message: "Allow?", updated: now.addingTimeInterval(-5), appBundleID: "x")
		let log = AgentSession(id: "s", tool: .claude, cwd: "/a", state: .working, message: nil, updated: now, appBundleID: nil)
		XCTAssertEqual(TranscriptSessions.merge(hooks: [hook], logs: [log]).first?.state, .waiting, "a question is never hidden by the log")
		var done = hook; done.state = .done
		let merged = TranscriptSessions.merge(hooks: [done], logs: [log])
		XCTAssertEqual(merged.first?.state, .working, "the log shows it started again")
		XCTAssertEqual(merged.first?.appBundleID, "x", "and the app it came from is kept")
		XCTAssertEqual(TranscriptSessions.merge(hooks: [], logs: [log]).count, 1)
		XCTAssertEqual(TranscriptSessions.merge(hooks: [hook], logs: []).count, 1)
	}

	func testScanReadsRecentLogsInAFolderAndIgnoresOldOnes() throws {
		let dir = FileManager.default.temporaryDirectory.appendingPathComponent("projects-\(UUID().uuidString)", isDirectory: true)
		let project = dir.appendingPathComponent("-Users-x-Yana-AI", isDirectory: true)
		try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: dir) }
		let fresh = project.appendingPathComponent("abc.jsonl"), old = project.appendingPathComponent("old.jsonl")
		try [line("user"), line("assistant")].joined(separator: "\n").write(to: fresh, atomically: true, encoding: .utf8)
		try line("assistant").write(to: old, atomically: true, encoding: .utf8)
		try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-3_600)], ofItemAtPath: old.path)
		let found = TranscriptSessions.scan(root: dir)
		XCTAssertEqual(found.map(\.id), ["abc"]); XCTAssertEqual(found.first?.state, .working); XCTAssertEqual(found.first?.project, "Yana-AI")
		XCTAssertTrue(TranscriptSessions.scan(root: dir.appendingPathComponent("missing")).isEmpty)
	}
}

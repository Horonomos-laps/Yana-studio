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

	func testWhatThePersonTypedIsReadButToolResultsAndSystemNotesAreNot() {
		func user(_ content: String, meta: Bool = false) -> String {
			#"{"type":"user","cwd":"/a","isMeta":\#(meta),"message":{"role":"user","content":\#(content)}}"#
		}
		let tail = [
			user(#""Sửa lỗi\nnút bấm""#),
			line("assistant", tool: true),
			user(#"[{"type":"tool_result","content":"ok"}]"#),
			user(#""<system-reminder>x</system-reminder>""#),
			user(#""caveat""#, meta: true),
		].joined(separator: "\n")
		let info = TranscriptSessions.parse(tail: tail, id: "s", modified: now)
		XCTAssertEqual(info.lastPrompt, "Sửa lỗi nút bấm", "the last thing typed, on one line")
		XCTAssertEqual(TranscriptSessions.typedText([["type": "text", "text": "hello"], ["type": "text", "text": "world"]]), "hello world")
		XCTAssertNil(TranscriptSessions.typedText("[Request interrupted by user]")); XCTAssertNil(TranscriptSessions.typedText(nil))
		XCTAssertEqual(TranscriptSessions.typedText(String(repeating: "x", count: 500))?.count, TranscriptSessions.maxPrompt)
		let session = TranscriptSessions.session(from: TranscriptInfo(id: "s", cwd: "/a", lastRole: "assistant", lastHadToolUse: false,
		                                                              lastPrompt: "Hỏi gì đó", modified: now.addingTimeInterval(-2)), now: now)
		XCTAssertEqual(session?.message, "Hỏi gì đó")
	}

	func testProcessLinesAreReadAndOnlyClaudeIsRecognized() {
		let output = """
		  101     1 /Applications/Yana.app/Contents/Applications/Yana Studio.app/Contents/MacOS/Yana Studio
		  202   101 /Applications/Yana.app/Contents/Applications/Yana Studio.app/Contents/Frameworks/Helper --type=utility
		  303   202 /bin/zsh -il
		  404   303 claude --resume abc
		  505   303 node /Users/x/.npm/_npx/@anthropic-ai/claude-code/cli.js
		  606   303 /opt/homebrew/bin/claude
		  707   303 claude-code-guide thing
		bad line
		"""
		let entries = ProcessTable.parse(output)
		XCTAssertEqual(entries.count, 7); XCTAssertEqual(entries.first?.pid, 101); XCTAssertEqual(entries[3].parent, 303)
		XCTAssertEqual(entries.filter { ProcessTable.isClaude($0.command) }.map(\.pid), [404, 505, 606])
	}

	func testTheAppIsFoundByWalkingUpTheParents() {
		let entries = [ProcessTable.Entry(pid: 101, parent: 1, command: "app"), ProcessTable.Entry(pid: 202, parent: 101, command: "helper"),
		               ProcessTable.Entry(pid: 303, parent: 202, command: "zsh"), ProcessTable.Entry(pid: 404, parent: 303, command: "claude")]
		let app = ProcessTable.ancestorApp(of: 404, entries: entries) { $0 == 101 ? "link.vutam.yana.studio" : nil }
		XCTAssertEqual(app, "link.vutam.yana.studio")
		XCTAssertNil(ProcessTable.ancestorApp(of: 404, entries: entries) { _ in nil }, "no app above it")
		XCTAssertNil(ProcessTable.ancestorApp(of: 999, entries: entries) { _ in "x" }, "an unknown process")
		XCTAssertNotNil(ProcessTable.folder(of: ProcessInfo.processInfo.processIdentifier), "the system gives a process's folder")
	}
}

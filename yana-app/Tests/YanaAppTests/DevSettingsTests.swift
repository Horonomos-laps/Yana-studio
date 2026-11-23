import XCTest
@testable import YanaApp

final class BranchNamingTests: XCTestCase {
	private let fixed = Date(timeIntervalSince1970: 1_700_000_000)
	private let id = UUID(uuidString: "ABCDEF12-0000-0000-0000-000000000000")!

	func testSlugKeepsLettersAndDigitsOnly() {
		XCTAssertEqual(BranchNaming.slug("Fix the Login bug!"), "fix-the-login-bug")
	}

	func testSlugFoldsVietnameseLetters() {
		XCTAssertEqual(BranchNaming.slug("Sửa lỗi đăng nhập"), "sua-loi-dang-nhap")
	}

	func testSlugOfEmptyAndSymbolsIsEmpty() {
		XCTAssertEqual(BranchNaming.slug(""), "")
		XCTAssertEqual(BranchNaming.slug("!!! ???"), "")
	}

	func testSlugIsCappedAndNeverEndsWithDash() {
		let long = String(repeating: "abc ", count: 40)
		let slug = BranchNaming.slug(long)
		XCTAssertLessThanOrEqual(slug.count, 40)
		XCTAssertFalse(slug.hasSuffix("-"))
	}

	func testNameFillsEveryPlaceholder() {
		let name = BranchNaming.name(prefix: "yana/", template: "{feature}-{branch}-{uuid}-{ts}-{date}",
		                             feature: "Add tests", branch: "main", now: fixed, uuid: id,
		                             timeZone: TimeZone(identifier: "UTC")!)
		XCTAssertEqual(name, "yana/add-tests-main-abcdef12-1700000000-2023-11-14")
	}

	func testDateFollowsTheGivenTimeZone() {
		let seoul = TimeZone(identifier: "Asia/Seoul")!
		let name = BranchNaming.name(prefix: "", template: "{date}-{time}", feature: "", branch: "", now: fixed, timeZone: seoul)
		XCTAssertEqual(name, "2023-11-15-071320")
	}

	func testBlankTemplateFallsBackToFeature() {
		XCTAssertEqual(BranchNaming.name(prefix: "yana/", template: "  ", feature: "Hello", branch: ""), "yana/hello")
	}

	func testSanitizeRemovesWhatGitForbids() {
		XCTAssertEqual(BranchNaming.sanitizeRef("a b~c^d:e?f*g[h"), "a-b-c-d-e-f-g-h")
		XCTAssertEqual(BranchNaming.sanitizeRef("a..b"), "a.b")
		XCTAssertEqual(BranchNaming.sanitizeRef("-lead/"), "lead")
		XCTAssertEqual(BranchNaming.sanitizeRef("topic.lock"), "topic")
		XCTAssertEqual(BranchNaming.sanitizeRef("x//y"), "x/y")
	}

	func testSanitizeOfNothingGivesAValidFallback() {
		XCTAssertEqual(BranchNaming.sanitizeRef(""), "yana/work")
		XCTAssertEqual(BranchNaming.sanitizeRef("///"), "yana/work")
	}

	func testHostileFeatureTextCannotEscapeTheRefName() {
		let name = BranchNaming.name(prefix: "yana/", template: "{feature}", feature: "x; rm -rf / $(id)", branch: "")
		XCTAssertEqual(name, "yana/x-rm-rf-id")
	}
}

final class WorktreeParseTests: XCTestCase {
	private let sample = """
	worktree /repo
	HEAD aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
	branch refs/heads/main

	worktree /repo-feat
	HEAD bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
	branch refs/heads/feat/x
	locked reason

	worktree /repo-det
	HEAD cccccccccccccccccccccccccccccccccccccccc
	detached
	prunable gitdir file points to non-existent location
	"""

	func testParsesAllBlocksAndMarksTheFirstAsMain() {
		let list = Worktrees.parse(porcelain: sample)
		XCTAssertEqual(list.count, 3)
		XCTAssertTrue(list[0].isMain)
		XCTAssertEqual(list[0].branch, "main")
		XCTAssertEqual(list[1].branch, "feat/x")
		XCTAssertTrue(list[1].locked)
		XCTAssertTrue(list[2].detached)
		XCTAssertTrue(list[2].prunable)
		XCTAssertNil(list[2].branch)
	}

	func testEmptyOutputGivesNoEntries() {
		XCTAssertTrue(Worktrees.parse(porcelain: "").isEmpty)
	}

	func testPathsWithSpacesSurvive() {
		let list = Worktrees.parse(porcelain: "worktree /Volumes/Dự án/Yana AI\nHEAD abc\nbranch refs/heads/main\n")
		XCTAssertEqual(list.first?.path, "/Volumes/Dự án/Yana AI")
	}

	private func entry(_ path: String, main: Bool = false, locked: Bool = false) -> WorktreeEntry {
		WorktreeEntry(path: path, head: "", branch: nil, detached: false, locked: locked, prunable: false, isMain: main)
	}

	func testSurplusListsOldestBeyondKeepAndSkipsProtected() {
		let all = [entry("/m", main: true), entry("/a"), entry("/b"), entry("/c"), entry("/d", locked: true), entry("/cur")]
		let ages: [String: TimeInterval] = ["/a": 10, "/b": 20, "/c": 30, "/d": 1, "/cur": 2]
		let out = Worktrees.surplus(all, keep: 1, protecting: "/cur") { ages[$0.path] ?? 0 }
		XCTAssertEqual(out.map(\.path), ["/a", "/b"])
	}

	func testSurplusIsEmptyWhenWithinTheLimit() {
		let all = [entry("/m", main: true), entry("/a")]
		XCTAssertTrue(Worktrees.surplus(all, keep: 5, protecting: "/x") { _ in 0 }.isEmpty)
	}
}

final class HookScanTests: XCTestCase {
	private let json = """
	{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[
	  {"type":"command","command":"YANA_GUARDED_HOOK=1 \\"${CLAUDE_PROJECT_DIR}/core/hooks/guard.sh\\" --x","timeout":5},
	  {"type":"command","command":"echo hello"}]}],
	  "Stop":[{"hooks":[{"type":"command","command":"node /p/.claude/hooks/gone.js"}]}]}}
	""".data(using: .utf8)!

	func testReadsEventsMatchersAndCommands() {
		let list = HookScan.parse(json: json, source: "project", projectDir: "/p") { $0 == "/p/core/hooks/guard.sh" }
		XCTAssertEqual(list.count, 3)
		XCTAssertEqual(list.filter { $0.event == "PreToolUse" }.count, 2)
		XCTAssertEqual(list.first { $0.event == "Stop" }?.matcher, "*")
	}

	func testFindsTheScriptBehindEnvPrefixAndProjectVariable() {
		let list = HookScan.parse(json: json, source: "project", projectDir: "/p") { _ in true }
		XCTAssertEqual(list.first { $0.command.contains("guard.sh") }?.script, "/p/core/hooks/guard.sh")
	}

	func testFlagsOnlyScriptsThatAreMissing() {
		let list = HookScan.parse(json: json, source: "project", projectDir: "/p") { $0 == "/p/core/hooks/guard.sh" }
		XCTAssertFalse(list.first { $0.command.contains("guard.sh") }!.scriptMissing)
		XCTAssertTrue(list.first { $0.command.contains("gone.js") }!.scriptMissing)
		XCTAssertFalse(list.first { $0.command == "echo hello" }!.scriptMissing)
	}

	// Regression: a project path with a space ("/Volumes/Dự án/...") used to be cut in two,
	// so a hook that exists was reported as missing.
	func testProjectPathWithSpacesIsNotCutInHalf() {
		let json = """
		{"hooks":{"PostToolUse":[{"matcher":".*","hooks":[{"type":"command","command":"YANA_GUARDED_HOOK=\\"${CLAUDE_PROJECT_DIR}/.claude/hooks/audit-log.sh\\" bash \\"${CLAUDE_PROJECT_DIR}/.claude/hooks/hook-timeout-guard.sh\\""}]}]}}
		""".data(using: .utf8)!
		let dir = "/Volumes/Dự án/Yana AI"
		let present: Set<String> = ["\(dir)/.claude/hooks/audit-log.sh", "\(dir)/.claude/hooks/hook-timeout-guard.sh"]
		let list = HookScan.parse(json: json, source: "p", projectDir: dir) { present.contains($0) }
		XCTAssertEqual(list.count, 1)
		XCTAssertEqual(list[0].script, "\(dir)/.claude/hooks/audit-log.sh")
		XCTAssertFalse(list[0].scriptMissing)
	}

	func testMissingWrapperScriptIsStillReported() {
		let json = """
		{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"bash \\"/a b/run.sh\\" \\"/a b/guard.sh\\""}]}]}}
		""".data(using: .utf8)!
		let list = HookScan.parse(json: json, source: "p", projectDir: "/p") { $0 == "/a b/run.sh" }
		XCTAssertTrue(list[0].scriptMissing)
	}

	func testBadOrEmptyJsonGivesNoHooks() {
		XCTAssertTrue(HookScan.parse(json: Data("not json".utf8), source: "s", projectDir: "/p") { _ in true }.isEmpty)
		XCTAssertTrue(HookScan.parse(json: Data("{}".utf8), source: "s", projectDir: "/p") { _ in true }.isEmpty)
	}
}

final class GitPrefsTests: XCTestCase {
	private func defaults() -> UserDefaults {
		let name = "yana.tests.\(UUID().uuidString)"
		let d = UserDefaults(suiteName: name)!
		d.removePersistentDomain(forName: name)
		return d
	}

	func testDefaultsSendNothing() {
		XCTAssertNil(GitPrefs.instruction(defaults()))
	}

	func testEachChangedSettingAddsItsOwnInstruction() {
		let d = defaults()
		d.set("team/", forKey: GitPrefs.prefixKey)
		d.set("squash", forKey: GitPrefs.mergeKey)
		d.set(false, forKey: GitPrefs.draftKey)
		d.set(true, forKey: GitPrefs.leaseKey)
		d.set("Use conventional commits.", forKey: GitPrefs.commitKey)
		let text = GitPrefs.instruction(d) ?? ""
		XCTAssertTrue(text.contains("team/"))
		XCTAssertTrue(text.contains("squash"))
		XCTAssertTrue(text.contains("not as drafts"))
		XCTAssertTrue(text.contains("--force-with-lease"))
		XCTAssertTrue(text.contains("Use conventional commits."))
	}

	func testWhitespaceOnlyGuidanceIsIgnored() {
		let d = defaults()
		d.set("   \n ", forKey: GitPrefs.commitKey)
		XCTAssertNil(GitPrefs.instruction(d))
	}
}

// The string table is built with Dictionary(uniqueKeysWithValues:), which crashes the app at launch on a repeated key.
final class StringTableTests: XCTestCase {
	func testNoStringKeyIsRepeated() {
		var seen = Set<String>(), repeated: [String] = []
		for row in allStringRows where !seen.insert(row.key).inserted { repeated.append(row.key) }
		XCTAssertEqual(repeated, [])
	}

	func testEveryRowHasTextInAllThreeLanguages() {
		let empty = allStringRows.filter { $0.vi.isEmpty || $0.en.isEmpty || $0.ko.isEmpty }.map(\.key)
		XCTAssertEqual(empty, [])
	}

	func testFormatStringsTakeTheSameNumberOfArguments() {
		// Counts %@ and %d, including the numbered forms (%1$@) some languages need to reorder arguments.
		let spec = try! NSRegularExpression(pattern: "%(\\d+\\$)?[@d]")
		func count(_ s: String) -> Int { spec.numberOfMatches(in: s, range: NSRange(s.startIndex..., in: s)) }
		for row in allStringRows where row.en.contains("%") {
			XCTAssertEqual(Set([row.vi, row.en, row.ko].map(count)).count, 1, row.key)
		}
	}
}

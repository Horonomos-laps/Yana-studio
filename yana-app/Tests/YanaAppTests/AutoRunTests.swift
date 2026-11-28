import XCTest
@testable import YanaApp

@MainActor
final class AutoRunTests: XCTestCase {
	// Only a grant kept outside the folder covers the person's own turn (yana-rt 1.5.6).
	func testTheAppAsksForAPersonalGrant() {
		let args = AutoRunStore.grantArguments("command.execute", minutes: 30, scope: ["--allow", "cargo test"])
		XCTAssertEqual(Array(args.prefix(2)), ["lease", "grant"])
		XCTAssertTrue(args.contains("--personal"))
		XCTAssertTrue(args.contains(AutoRunStore.subject))
		XCTAssertEqual(args.last, "--json")
	}

	func testAnOlderRuntimeIsNamedAsSuch() {
		XCTAssertEqual(AutoRunStore.problem("error: unexpected argument '--personal' found"), L("auto.needsNewRt"))
		XCTAssertEqual(AutoRunStore.problem("flock-v1 protocol marker missing"), L("auto.notInstalledHere"))
		XCTAssertEqual(AutoRunStore.problem("disk full"), "disk full")
		XCTAssertEqual(AutoRunStore.problem(""), "")
	}

	// yana-rt only runs its own short safe list on a grant; offering more would promise what never happens.
	func testTheAllowedListHoldsNothingTheRuntimeWouldStillAsk() {
		for entry in ["make", "npm run", "pnpm test", "yarn test", "pytest", "python3 -m pytest"] {
			XCTAssertFalse(AutoRunStore.allow.contains(entry), entry)
		}
		XCTAssertTrue(AutoRunStore.allow.contains("cargo test"))
	}

	func testTheExplanationSaysCommandsAreNotIsolated() {
		let row = allStringRows.first { $0.key == "auto.explain" }!
		XCTAssertTrue(row.vi.contains("không được cách ly"))
		XCTAssertTrue(row.en.contains("not isolated"))
		XCTAssertTrue(row.ko.contains("격리"))
	}
}

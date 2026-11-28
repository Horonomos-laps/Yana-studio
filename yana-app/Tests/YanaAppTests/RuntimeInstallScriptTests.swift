import XCTest
@testable import YanaApp

final class RuntimeInstallScriptTests: XCTestCase {
	// The script lines the shell runs, without comments.
	private var commands: [String] {
		RuntimeInstallScript.text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
			.filter { !$0.isEmpty && !$0.hasPrefix("#") }
	}

	// `yana-ai install` sets up a project folder, asks a question and audits that folder. The update
	// terminal starts in the home folder, so the step stalled the update before yana-rt (1.1.0).
	func testUpdateNeverSetsUpAProject() {
		XCTAssertFalse(commands.contains { $0.hasPrefix("yana-ai install") })
	}

	// The real binary must be copied after pipx, which also declares a launcher named yana-rt.
	func testRealRuntimeIsCopiedAfterThePythonPackage() throws {
		let pipx = try XCTUnwrap(commands.lastIndex { $0.contains("pipx install yana-ai") })
		let cargo = try XCTUnwrap(commands.firstIndex(of: "cargo install yana-rt"))
		let copy = try XCTUnwrap(commands.firstIndex { $0.hasPrefix("cp \"$HOME/.cargo/bin/yana-rt\"") })
		XCTAssertLessThan(pipx, cargo)
		XCTAssertLessThan(cargo, copy)
	}
}

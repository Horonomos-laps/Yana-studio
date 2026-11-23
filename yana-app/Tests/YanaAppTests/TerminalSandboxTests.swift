import Darwin
import XCTest
@testable import YanaApp

final class TerminalSandboxProfileTests: XCTestCase {
	func testProfileAllowsWritesOnlyToTheListedPlaces() {
		let p = TerminalSandbox.profile(folder: "/work/app", home: "/Users/me", blockNetwork: false)
		XCTAssertTrue(p.hasPrefix("(version 1)\n(allow default)\n"))
		XCTAssertTrue(p.contains("(subpath \"/work/app\")"))
		XCTAssertTrue(p.contains("(subpath \"/private/tmp\")"))
		XCTAssertTrue(p.contains("(subpath \"/Users/me/.cache\")"))
		XCTAssertTrue(p.contains("(literal \"/Users/me/.zsh_history\")"))
		XCTAssertTrue(p.contains("(deny file-write* (require-not (require-any"))
	}

	func testNetworkIsBlockedOnlyWhenAsked() {
		XCTAssertFalse(TerminalSandbox.profile(folder: "/a", home: "/h", blockNetwork: false).contains("network"))
		XCTAssertTrue(TerminalSandbox.profile(folder: "/a", home: "/h", blockNetwork: true).contains("(deny network*)"))
	}

	func testQuotesAndBackslashesInAPathCannotBreakOutOfTheProfile() {
		let p = TerminalSandbox.profile(folder: "/w/a\"b)(allow file-write* (subpath \"/\"))\\", home: "/h", blockNetwork: false)
		XCTAssertTrue(p.contains("(subpath \"/w/a\\\"b)(allow file-write* (subpath \\\"/\\\"))\\\\\")"))
		XCTAssertEqual(p.components(separatedBy: "(allow default)").count, 2)
	}

	func testPathsWithSpacesAndAccentsSurvive() {
		let p = TerminalSandbox.profile(folder: "/Volumes/Dự án/Yana AI", home: "/Users/vũ", blockNetwork: false)
		XCTAssertTrue(p.contains("(subpath \"/Volumes/Dự án/Yana AI\")"))
		XCTAssertTrue(p.contains("(subpath \"/Users/vũ/.npm\")"))
	}

	func testCanonicalFollowsLinks() {
		XCTAssertEqual(TerminalSandbox.canonical("/tmp"), "/private/tmp")
		XCTAssertEqual(TerminalSandbox.canonical("/private/tmp"), "/private/tmp")
		XCTAssertEqual(TerminalSandbox.canonical("/"), "/")
	}

	func testCanonicalKeepsTheMissingTailOfAFolderThatDoesNotExistYet() {
		XCTAssertEqual(TerminalSandbox.canonical("/tmp/yana-not-made-yet/a/b"), "/private/tmp/yana-not-made-yet/a/b")
		XCTAssertEqual(TerminalSandbox.canonical("/definitely-not-here-xyz"), "/definitely-not-here-xyz")
	}

	func testLaunchStartsTheShellUnderSandboxExecAsALoginShell() {
		let run = TerminalSandbox.launch(shell: "/bin/zsh", folder: "/tmp/x", home: NSHomeDirectory(), blockNetwork: true)
		XCTAssertEqual(run.executable, "/usr/bin/sandbox-exec")
		XCTAssertEqual(run.args.first, "-p")
		XCTAssertEqual(Array(run.args.suffix(2)), ["/bin/zsh", "-l"])
		XCTAssertTrue(run.args[1].contains("(deny network*)"))
		XCTAssertTrue(run.args[1].contains("/private/tmp/x"))
	}

	func testSettingsAreOffByDefaultAndReadFromDefaults() {
		let name = "yana.tests.sbx.\(UUID().uuidString)"
		let d = UserDefaults(suiteName: name)!
		d.removePersistentDomain(forName: name)
		XCTAssertEqual(TerminalSandbox.current(d), TerminalSandbox.Policy(enabled: false, blockNetwork: false))
		d.set(true, forKey: TerminalSandbox.enabledKey)
		d.set(true, forKey: TerminalSandbox.blockNetworkKey)
		XCTAssertEqual(TerminalSandbox.current(d), TerminalSandbox.Policy(enabled: true, blockNetwork: true))
	}

	func testEverySandboxStringExistsInAllLanguages() {
		for key in ["sbx.title", "sbx.enable", "sbx.noNetwork", "sbx.unavailable", "sbx.note", "sbx.tabHelp"] {
			XCTAssertNotEqual(L(key), key, key)
		}
	}
}

// These start a real sandboxed process, so they show the profile does what it says.
final class TerminalSandboxEnforcementTests: XCTestCase {
	private var root = ""
	private var project = ""
	private var outside = ""

	override func setUpWithError() throws {
		try XCTSkipUnless(TerminalSandbox.isAvailable, "sandbox-exec is not on this Mac")
		// Under the home folder, not the temp folders: those are writable by design, so they prove nothing.
		root = NSHomeDirectory() + "/.yana-sbx-test-\(UUID().uuidString)"
		project = root + "/project"
		outside = root + "/outside"
		try FileManager.default.createDirectory(atPath: project, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(atPath: outside, withIntermediateDirectories: true)
	}

	override func tearDown() {
		// Only the folder this test made, named by the check below.
		if root.contains("/.yana-sbx-test-") { try? FileManager.default.removeItem(atPath: root) }
	}

	private func run(_ program: String, _ args: [String], blockNetwork: Bool = false) throws -> (status: Int32, out: String, err: String) {
		let profile = TerminalSandbox.profile(folder: TerminalSandbox.canonical(project), home: TerminalSandbox.canonical(NSHomeDirectory()),
		                                      blockNetwork: blockNetwork)
		let p = Process()
		p.executableURL = URL(fileURLWithPath: TerminalSandbox.executable)
		p.arguments = ["-p", profile, program] + args
		p.currentDirectoryURL = URL(fileURLWithPath: project)
		let out = Pipe(), err = Pipe()
		p.standardOutput = out
		p.standardError = err
		try p.run()
		p.waitUntilExit()
		return (p.terminationStatus, String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
		        String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
	}

	func testTheShellCanWriteInsideTheProject() throws {
		let r = try run("/bin/sh", ["-c", "echo ok > '\(project)/in.txt'"])
		XCTAssertEqual(r.status, 0, r.err)
		XCTAssertTrue(FileManager.default.fileExists(atPath: project + "/in.txt"))
	}

	// A project folder reached through a link names the real folder in the profile, so writes there still work.
	func testAProjectGivenAsASymlinkIsStillWritable() throws {
		let link = root + "/link"
		try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: project)
		let run = TerminalSandbox.launch(shell: "/bin/sh", folder: link, home: NSHomeDirectory(), blockNetwork: false)
		XCTAssertTrue(run.args[1].contains("(subpath \"\(TerminalSandbox.canonical(project))\")"))
		let p = Process()
		p.executableURL = URL(fileURLWithPath: run.executable)
		p.arguments = [run.args[0], run.args[1], "/bin/sh", "-c", "echo ok > '\(project)/via-link.txt'"]
		p.standardError = Pipe()
		try p.run()
		p.waitUntilExit()
		XCTAssertEqual(p.terminationStatus, 0)
		XCTAssertTrue(FileManager.default.fileExists(atPath: project + "/via-link.txt"))
	}

	func testTheShellCannotWriteOutsideTheProject() throws {
		let r = try run("/bin/sh", ["-c", "echo no > '\(outside)/out.txt'"])
		XCTAssertNotEqual(r.status, 0)
		XCTAssertTrue(r.err.contains("Operation not permitted"), r.err)
		XCTAssertFalse(FileManager.default.fileExists(atPath: outside + "/out.txt"))
	}

	func testTheShellCannotDeleteOrRenameOutsideTheProject() throws {
		let target = outside + "/keep.txt"
		try "keep".write(toFile: target, atomically: true, encoding: .utf8)
		_ = try run("/bin/sh", ["-c", "rm -f '\(target)'; mv '\(target)' '\(outside)/moved.txt'"])
		XCTAssertEqual(try String(contentsOfFile: target, encoding: .utf8), "keep")
		XCTAssertFalse(FileManager.default.fileExists(atPath: outside + "/moved.txt"))
	}

	func testTheShellCanStillReadOutsideTheProject() throws {
		try "hello".write(toFile: outside + "/read.txt", atomically: true, encoding: .utf8)
		let r = try run("/bin/cat", [outside + "/read.txt"])
		XCTAssertEqual(r.out, "hello")
	}

	func testTheTempFolderStaysWritableSoToolsKeepWorking() throws {
		let r = try run("/bin/sh", ["-c", "t=$(mktemp) && echo x > \"$t\" && rm \"$t\""])
		XCTAssertEqual(r.status, 0, r.err)
	}

	func testNetworkWorksUnlessBlocked() throws {
		let server = socket(AF_INET, SOCK_STREAM, 0)
		XCTAssertGreaterThanOrEqual(server, 0)
		defer { close(server) }
		var addr = sockaddr_in()
		addr.sin_family = sa_family_t(AF_INET)
		addr.sin_addr.s_addr = inet_addr("127.0.0.1")
		addr.sin_port = 0
		let bound = withUnsafePointer(to: &addr) {
			$0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(server, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
		}
		XCTAssertEqual(bound, 0)
		XCTAssertEqual(listen(server, 4), 0)
		var len = socklen_t(MemoryLayout<sockaddr_in>.size)
		_ = withUnsafeMutablePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(server, $0, &len) } }
		let port = UInt16(bigEndian: addr.sin_port)
		let code = "import socket; s=socket.socket(); s.settimeout(3); s.connect(('127.0.0.1',\(port))); print('connected')"
		try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: "/usr/bin/python3"), "no python3 here")

		let open = try run("/usr/bin/python3", ["-c", code], blockNetwork: false)
		XCTAssertTrue(open.out.contains("connected"), open.err)
		let blocked = try run("/usr/bin/python3", ["-c", code], blockNetwork: true)
		XCTAssertFalse(blocked.out.contains("connected"))
		XCTAssertTrue(blocked.err.contains("Operation not permitted"), blocked.err)
	}

	func testAPathWithQuotesDoesNotLetTheShellWriteAnywhere() throws {
		let hostile = outside + "/a\"b)(allow file-write* (subpath \"/\"))"
		try FileManager.default.createDirectory(atPath: hostile, withIntermediateDirectories: true)
		let profile = TerminalSandbox.profile(folder: TerminalSandbox.canonical(hostile), home: TerminalSandbox.canonical(NSHomeDirectory()),
		                                      blockNetwork: false)
		let p = Process()
		p.executableURL = URL(fileURLWithPath: TerminalSandbox.executable)
		p.arguments = ["-p", profile, "/bin/sh", "-c", "echo no > '\(outside)/escape.txt'"]
		p.standardError = Pipe()
		try p.run()
		p.waitUntilExit()
		XCTAssertFalse(FileManager.default.fileExists(atPath: outside + "/escape.txt"))
	}
}

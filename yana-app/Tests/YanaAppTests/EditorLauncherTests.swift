import XCTest
@testable import YanaApp

final class EditorLauncherTests: XCTestCase {
	private var root: URL!
	private var app: URL { root.appendingPathComponent("Yana Studio.app") }
	private var checkout: URL { root.appendingPathComponent("vscode") }
	private var checkoutExtension: URL { checkout.appendingPathComponent("extensions/yana-agent") }

	override func setUpWithError() throws {
		root = FileManager.default.temporaryDirectory.appendingPathComponent("editor-launcher-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		try FileManager.default.removeItem(at: root)
	}

	private func addBridge(in extensionFolder: URL) throws {
		let features = extensionFolder.appendingPathComponent("features")
		try FileManager.default.createDirectory(at: features, withIntermediateDirectories: true)
		try Data().write(to: features.appendingPathComponent("app-bridge.js"))
	}

	private func addBundledBridge() throws {
		try addBridge(in: app.appendingPathComponent("Contents/Resources/app/extensions/yana-agent"))
	}

	// A source folder left on a developer's Mac replaced the newer packaged extension (1.1.1).
	func testPackagedBridgeWinsOverSourceFolder() throws {
		try addBundledBridge()
		try addBridge(in: checkoutExtension)
		XCTAssertNil(EditorLauncher.devExtension(app: app, checkout: checkout.path))
	}

	func testSourceFolderFillsInWhenPackagedStudioHasNoBridge() throws {
		try addBridge(in: checkoutExtension)
		XCTAssertEqual(EditorLauncher.devExtension(app: app, checkout: checkout.path), checkoutExtension.path)
	}

	func testNothingIsLoadedWhenNeitherHasTheBridge() {
		XCTAssertNil(EditorLauncher.devExtension(app: app, checkout: checkout.path))
		XCTAssertNil(EditorLauncher.devExtension(app: app, checkout: ""))
		XCTAssertNil(EditorLauncher.devExtension(app: nil, checkout: String(repeating: "a", count: 65_536)))
		XCTAssertNil(EditorLauncher.devExtension(app: app, checkout: "../../\u{0}\r\n"))
	}

	func testPackagedBridgeIsReported() throws {
		XCTAssertFalse(EditorLauncher.hasPackagedBridge(app: app))
		XCTAssertFalse(EditorLauncher.hasPackagedBridge(app: nil))
		try addBundledBridge()
		XCTAssertTrue(EditorLauncher.hasPackagedBridge(app: app))
	}
}

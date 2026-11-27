import XCTest
@testable import YanaApp

final class InPlaceUpdaterTests: XCTestCase {
	private let key = Data(repeating: 7, count: 32).base64EncodedString()

	private func on(_ feed: Any?, _ publicKey: Any?) -> Bool {
		var info: [String: Any] = [:]
		info["SUFeedURL"] = feed
		info["SUPublicEDKey"] = publicKey
		return InPlaceUpdater.isConfigured(info)
	}

	func testNeedsAFeedAndAKey() {
		XCTAssertTrue(on("https://example.com/appcast.xml", key))
		XCTAssertFalse(on(nil, nil))
		XCTAssertFalse(on("https://example.com/appcast.xml", nil))
		XCTAssertFalse(on(nil, key))
		XCTAssertFalse(on("", ""))
		XCTAssertFalse(on(1, 2))
	}

	func testAKeyMustBeAnEd25519PublicKey() {
		for bad in ["not base64 !", Data(repeating: 1, count: 31).base64EncodedString(),
		            Data(repeating: 1, count: 64).base64EncodedString(), String(repeating: "A", count: 65536), "\u{0}"] {
			XCTAssertFalse(on("https://example.com/appcast.xml", bad), String(bad.prefix(20)))
		}
	}

	func testOnlyHttpsExceptThisMac() {
		XCTAssertTrue(on("http://127.0.0.1:8765/appcast.xml", key))
		for bad in ["http://example.com/appcast.xml", "http://127.0.0.1.example.com/a", "file:///tmp/appcast.xml",
		            "ftp://example.com/a", "appcast.xml", "https://"] {
			XCTAssertFalse(on(bad, key), bad)
		}
	}
}

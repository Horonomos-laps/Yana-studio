import XCTest
@testable import YanaApp

final class DictationTextTests: XCTestCase {
	func testSpokenWordsGoAfterTheDraftWithOneSpace() {
		XCTAssertEqual(DictationText.merge(base: "Hello", spoken: "world"), "Hello world")
	}

	func testNoSpaceIsAddedWhenTheDraftIsEmptyOrEndsInWhitespace() {
		XCTAssertEqual(DictationText.merge(base: "", spoken: "hello"), "hello")
		XCTAssertEqual(DictationText.merge(base: "Hello ", spoken: "world"), "Hello world")
		XCTAssertEqual(DictationText.merge(base: "Line one\n", spoken: "line two"), "Line one\nline two")
	}

	func testSilenceChangesNothing() {
		XCTAssertEqual(DictationText.merge(base: "Hello", spoken: ""), "Hello")
		XCTAssertEqual(DictationText.merge(base: "Hello", spoken: "  \n "), "Hello")
		XCTAssertEqual(DictationText.merge(base: "", spoken: ""), "")
	}

	func testSpokenTextIsTrimmed() {
		XCTAssertEqual(DictationText.merge(base: "A", spoken: "  b  "), "A b")
	}

	func testVietnameseTextKeepsItsAccents() {
		XCTAssertEqual(DictationText.merge(base: "Xin chào", spoken: "tôi là Yana"), "Xin chào tôi là Yana")
	}

	func testEachAppLanguageHasASpeechLocale() {
		XCTAssertEqual(DictationText.localeIdentifier(for: .vi), "vi-VN")
		XCTAssertEqual(DictationText.localeIdentifier(for: .en), "en-US")
		XCTAssertEqual(DictationText.localeIdentifier(for: .ko), "ko-KR")
		XCTAssertEqual(Set(Lang.allCases.map(DictationText.localeIdentifier)).count, Lang.allCases.count)
	}
}

final class DictationSetupTests: XCTestCase {
	func testEveryFailureHasTextInTheStringTable() {
		let failures: [DictationFailure] = [.micDenied, .speechDenied, .noOnDevice, .unavailable, .noMic]
		for failure in failures {
			let key = try? XCTUnwrap(failure.messageKey)
			XCTAssertNotNil(key)
			XCTAssertNotEqual(L(key ?? ""), key, "no text for \(String(describing: key))")
		}
		XCTAssertNil(DictationFailure.other("x").messageKey)
	}

	func testPermissionFailuresPointToTheRightSettingsPane() {
		XCTAssertTrue(DictationFailure.micDenied.settingsURL?.absoluteString.hasSuffix("Privacy_Microphone") ?? false)
		XCTAssertTrue(DictationFailure.speechDenied.settingsURL?.absoluteString.hasSuffix("Privacy_SpeechRecognition") ?? false)
		XCTAssertNil(DictationFailure.noOnDevice.settingsURL)
	}

	// Without these two reasons macOS ends the app the moment a permission is requested.
	func testInfoPlistExplainsTheMicrophoneAndSpeechPermissions() throws {
		let plist = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
			.appendingPathComponent("Info.plist")
		let data = try Data(contentsOf: plist)
		let info = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
		for key in ["NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription"] {
			let text = try XCTUnwrap(info[key] as? String, key)
			XCTAssertFalse(text.trimmingCharacters(in: .whitespaces).isEmpty, key)
		}
	}

	func testMicrophoneIconIsInTheIconSet() {
		XCTAssertNotNil(FBIcons.markup["mic"])
		XCTAssertNotNil(FBIcons.image("mic"))
	}

	func testDictateShortcutIsBoundAndRebindable() {
		let store = ShortcutStore(defaults: UserDefaults(suiteName: "yana.tests.\(UUID().uuidString)")!)
		XCTAssertEqual(store.effective(.dictate)?.display, "⌃⇧D")
		XCTAssertEqual(store.assign(Shortcut(key: "m", option: true, control: true), to: .dictate), .ok)
		XCTAssertNotNil(MenuAction(rawValue: ShortcutAction.dictate.rawValue))
	}
}

@MainActor
final class DictationEngineTests: XCTestCase {
	func testStartsIdleAndStoppingOrEditingWhileIdleDoesNothing() {
		let engine = DictationEngine()
		XCTAssertEqual(engine.state, .idle)
		XCTAssertFalse(engine.listening)
		engine.stop()
		engine.userEdited("anything")
		engine.clearFailure()
		XCTAssertEqual(engine.state, .idle)
	}

	// `swift test` has no Info.plist with the permission reasons, so a start must fail cleanly, not crash.
	func testStartingWithoutThePermissionReasonsFailsInsteadOfCrashing() async throws {
		try XCTSkipIf(Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") != nil, "this process has the reasons")
		let engine = DictationEngine()
		var applied: [String] = []
		engine.toggle(draft: "x", language: .en, allowServer: false) { applied.append($0) }
		try await Task.sleep(nanoseconds: 300_000_000)
		guard case .failed = engine.state else { return XCTFail("expected a failure, got \(engine.state)") }
		XCTAssertTrue(applied.isEmpty)
		engine.clearFailure()
		XCTAssertEqual(engine.state, .idle)
	}
}
